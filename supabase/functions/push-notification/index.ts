// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

console.log("Hello from Functions! (FCM V1)")

// Environment Variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// The user must set this secret with the entire JSON content of their service account
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT');

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: any
  schema: string
  old_record: null | any
}

// Function to get an access token from Google OAuth2
async function getAccessToken(serviceAccountJson: any) {
  const now = Math.floor(Date.now() / 1000);
  const hour = 3600;

  // 1. Create a simplified JWT content
  // Required claims for Google Service Account
  const jwtPayload = {
    iss: serviceAccountJson.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + hour,
    iat: now,
  };

  // 2. Sign the JWT with the private key
  const privateKey = await jose.importPKCS8(serviceAccountJson.private_key, 'RS256');
  const jwt = await new jose.SignJWT(jwtPayload)
    .setProtectedHeader({ alg: 'RS256' })
    .sign(privateKey);

  // 3. Exchange JWT for Access Token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json()

    if ((payload.table === 'messages' || payload.table === 'messages_dev') && payload.type === 'INSERT') {
      // Validate Service Account Secret
      if (!FCM_SERVICE_ACCOUNT_JSON) {
        console.error('FCM_SERVICE_ACCOUNT secret is missing');
        return new Response(JSON.stringify({ error: 'Configuration Error: FCM_SERVICE_ACCOUNT missing' }), { status: 500 });
      }

      const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
      const projectId = serviceAccount.project_id;
      
      const message = payload.record;
      const senderId = message.sender_id;
      
      const usersTable = payload.table === 'messages_dev' ? 'users_dev' : 'users';
      const tokensTable = payload.table === 'messages_dev' ? 'fcm_tokens_dev' : 'fcm_tokens';

      // Get Sender Name
      const { data: sender } = await supabase
        .from(usersTable)
        .select('username')
        .eq('id', senderId)
        .single();
        
      const senderName = sender?.username || 'New Message';

      // Get Recipients (Broadcast to all except sender)
      const { data: tokens, error: tokensError } = await supabase
        .from(tokensTable)
        .select('token')
        .neq('user_id', senderId);

      if (tokensError || !tokens || tokens.length === 0) {
        return new Response(JSON.stringify({ message: 'No recipients found' }), { status: 200 });
      }

      console.log(`Sending to ${tokens.length} devices...`);

      // Get Access Token
      const accessToken = await getAccessToken(serviceAccount);
      
      // Send to each token
      const notificationTitle = senderName;
      const notificationBody = message.message_type === 'text' ? message.content : `Sent a ${message.message_type}`;
      
      const sendPromises = tokens.map(async (t) => {
        const messagePayload = {
          message: {
            token: t.token,
            notification: {
              title: notificationTitle,
              body: notificationBody,
            },
            data: {
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              message_id: message.id,
              sender_id: senderId,
              type: 'new_message',
            },
            android: {
              priority: 'high',
              notification: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                channel_id: 'message_channel'
              }
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: notificationTitle,
                    body: notificationBody,
                  },
                  category: 'MESSAGE_CATEGORY',
                  "mutable-content": 1
                }
              }
            }
          }
        };

        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(messagePayload),
        });
        return res.json();
      });

      const results = await Promise.all(sendPromises);
      console.log('FCM Results:', results);

      return new Response(JSON.stringify({ results }), { 
        headers: { 'Content-Type': 'application/json' } 
      });
    }

    return new Response(JSON.stringify({ message: 'Not a message insert event' }), { headers: { 'Content-Type': 'application/json' } });

  } catch (error) {
    console.error('Error processing webhook:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
