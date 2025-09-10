# GitHub Pages Setup for VeggieConnect Payment Redirects

This guide will help you set up GitHub Pages as a free domain for payment redirects in your VeggieConnect application.

## Overview

GitHub Pages will host the payment success and cancel pages that users see after completing or cancelling their payments through PayMongo. These pages will:

1. Display a consistent design matching your app
2. Complete the order in Firestore
3. Redirect users back to your application
4. Handle different payment methods (GCash, GrabPay, PayMaya, Card)

## Setup Steps

### 1. Create a GitHub Repository

1. Go to [GitHub](https://github.com) and create a new repository
2. Name it `veggieconnect.github.io` (this will be your free domain)
3. Make it public
4. Initialize with a README

### 2. Upload the HTML Files

1. Clone your repository locally:
   ```bash
   git clone https://github.com/yourusername/veggieconnect.github.io.git
   cd veggieconnect.github.io
   ```

2. Copy the HTML files from your project:
   ```bash
   cp /path/to/veggieconnect/public/payment-success.html ./
   cp /path/to/veggieconnect/public/payment-cancel.html ./
   ```

3. Create an `index.html` file for the main page:
   ```html
   <!DOCTYPE html>
   <html lang="en">
   <head>
       <meta charset="UTF-8">
       <meta name="viewport" content="width=device-width, initial-scale=1.0">
       <title>VeggieConnect</title>
   </head>
   <body>
       <h1>Welcome to VeggieConnect</h1>
       <p>Your payment processing is complete.</p>
   </body>
   </html>
   ```

4. Commit and push the files:
   ```bash
   git add .
   git commit -m "Add payment redirect pages"
   git push origin main
   ```

### 3. Enable GitHub Pages

1. Go to your repository on GitHub
2. Click on "Settings" tab
3. Scroll down to "Pages" section
4. Under "Source", select "Deploy from a branch"
5. Choose "main" branch and "/ (root)" folder
6. Click "Save"

### 4. Deploy Order Completion Functions

You have two options for deploying the order completion functions:

#### Option A: Firebase Functions (Requires Blaze Plan)

1. Upgrade your Firebase project to Blaze plan: https://console.firebase.google.com/project/vegieconnect-6bd73/usage/details
2. Deploy the updated Cloud Functions:
   ```bash
   cd veggieconnect/functions
   firebase deploy --only functions
   ```
3. Note the function URLs:
   - `completeOrder`: `https://us-central1-your-project-id.cloudfunctions.net/completeOrder`
   - `paymongoWebhook`: `https://us-central1-your-project-id.cloudfunctions.net/paymongoWebhook`

#### Option B: Vercel (Free Alternative)

1. Deploy to Vercel (if not already done):
   ```bash
   cd veggieconnect/paymongo-api
   vercel --prod
   ```
2. The functions will be available at:
   - `completeOrder`: `https://paymongo-api-fawn.vercel.app/api/completeOrder`
   - `paymongoWebhook`: `https://paymongo-api-fawn.vercel.app/api/paymongoWebhook`

### 5. Update PayMongo Configuration

The configuration is already updated in your code, but verify these URLs:

- Success URL: `https://veggieconnect.github.io/payment-success.html`
- Cancel URL: `https://veggieconnect.github.io/payment-cancel.html`

### 6. Configure PayMongo Webhook

1. Go to your PayMongo dashboard
2. Navigate to Webhooks section
3. Add a new webhook with URL: `https://us-central1-your-project-id.cloudfunctions.net/paymongoWebhook`
4. Select events: `checkout.session.completed`
5. Save the webhook

### 7. Test the Integration

1. Make a test purchase in your app
2. Complete the payment through PayMongo
3. Verify you're redirected to the GitHub Pages success page
4. Check that the order is created in Firestore
5. Verify the payment method is correctly labeled

## File Structure

Your GitHub Pages repository should have:

```
veggieconnect.github.io/
├── index.html
├── payment-success.html
├── payment-cancel.html
└── README.md
```

## Customization

### Updating the Design

The HTML files use CSS that matches your app's design:
- Primary color: `#6CA04A` (green)
- Font: Quicksand
- Responsive design for mobile and desktop

### Adding App Deep Links

Update the JavaScript in the HTML files to use your app's custom URL scheme:

```javascript
// In payment-success.html and payment-cancel.html
const appUrl = `veggieconnect://order-success?orderId=${orderId}`;
```

### Updating Cloud Function URLs

If you change your Firebase project, update the Cloud Function URLs in the HTML files:

```javascript
// In payment-success.html
const response = await fetch('https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/completeOrder', {
    // ... rest of the code
});
```

## Troubleshooting

### Common Issues

1. **GitHub Pages not updating**: Wait 5-10 minutes for changes to propagate
2. **CORS errors**: Ensure your Cloud Functions have proper CORS headers
3. **Orders not completing**: Check Firebase Functions logs for errors
4. **Payment methods not showing**: Verify the payment method detection logic

### Debugging

1. Check browser console for JavaScript errors
2. Monitor Firebase Functions logs:
   ```bash
   firebase functions:log
   ```
3. Verify PayMongo webhook is receiving events
4. Check Firestore for order creation

## Security Considerations

1. The HTML pages are public, but they only display order information
2. Order completion requires valid order IDs
3. Cloud Functions handle the actual order processing
4. No sensitive data is stored in the HTML pages

## Maintenance

1. Update the HTML files when you change your app's design
2. Monitor Cloud Function performance
3. Keep PayMongo webhook configuration up to date
4. Test the flow regularly with different payment methods

## Support

If you encounter issues:

1. Check the GitHub Pages status: https://www.githubstatus.com/
2. Verify your repository settings
3. Check Firebase Functions logs
4. Test with different browsers and devices

The setup is now complete! Your users will be redirected to professional-looking pages after payment completion, and orders will be properly processed in Firestore.
