export const money = n => new Intl.NumberFormat("bn-BD",{style:"currency",currency:"BDT",maximumFractionDigits:2}).format(Number(n||0));
export const waUrl = message => `https://wa.me/${import.meta.env.VITE_WHATSAPP_NUMBER || "8801631421995"}?text=${encodeURIComponent(message)}`;
export const orderText = o => [
`মাসিক বাজার — অর্ডার ${o.order_no}`,
`নাম: ${o.customer_name}`,`মোবাইল: ${o.phone}`,
`ঠিকানা: ${[o.district,o.upazila,o.area,o.address].filter(Boolean).join(", ")}`,"","পণ্যের তালিকা:",
...(o.items||[]).map((x,i)=>`${i+1}. ${x.product_name}${x.brand_name?` (${x.brand_name})`:""} — ${x.quantity} ${x.unit} — ${x.unit_price==null?"দাম পরে নিশ্চিত হবে":money(x.line_total)}`),
"",`আংশিক মোট: ${money(o.subtotal)}`,"দাম, প্রাপ্যতা ও ডেলিভারি চার্জ ফোনে নিশ্চিত করা হবে।"
].join("\n");
