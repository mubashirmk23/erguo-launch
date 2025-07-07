import { serve } from "https://deno.land/std/http/server.ts";

// Load Cashfree credentials from Supabase secrets (environment variables)
const CASHFREE_APP_ID = Deno.env.get("CASHFREE_APP_ID") ?? "";
const CASHFREE_SECRET_KEY = Deno.env.get("CASHFREE_SECRET_KEY") ?? "";

// Ensure credentials are set
if (!CASHFREE_APP_ID || !CASHFREE_SECRET_KEY) {
  console.error("❌ Missing Cashfree API credentials.");
  throw new Error("Missing Cashfree API credentials");
}

// Start the server
serve(async (req) => {
  try {
    // Parse the request body
    const { amount, customerName, customerEmail, customerPhone } = await req.json();

    // Validate input parameters
    if (!amount || !customerName || !customerEmail || !customerPhone) {
      return new Response(JSON.stringify({ error: "Missing required parameters" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Generate a unique order ID
    const orderId = `order_${Date.now()}`;

    // Prepare request payload for Cashfree
    const payload = {
      order_id: orderId,
      order_amount: amount,
      order_currency: "INR",
      order_note: "Service Payment via Erguo",
      order_meta: {
        return_url: `https://yourapp.com/payment-success?order_id=${orderId}`,
        notify_url: `https://yourapp.com/payment-webhook`,
      },
      customer_details: {
        customer_id: `cust_${Date.now()}`,
        customer_name: customerName,
        customer_email: customerEmail,
        customer_phone: customerPhone,
      },
    };

    // Make request to Cashfree API
    const response = await fetch("https://sandbox.cashfree.com/pg/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-client-id": CASHFREE_APP_ID,
        "x-client-secret": CASHFREE_SECRET_KEY,
        "x-api-version": "2022-09-01",
      },
      body: JSON.stringify(payload),
    });

    // Parse response
    const data = await response.json();

    // Handle response from Cashfree
    if (response.ok && data.payment_session_id) {
      return new Response(JSON.stringify({ payment_session_id: data.payment_session_id }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } else {
      console.error("❌ Cashfree API Error:", data);
      return new Response(JSON.stringify({ error: data.message || "Failed to create payment session" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    console.error("❌ Server Error:", error);
    return new Response(JSON.stringify({ error: "Internal Server Error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
