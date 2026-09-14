-- 032_sender_profile_signature_html
-- Packet 10.4b C1. Same D-I words, HTML typography for Gmail.
-- Does not rewrite 031. 030 stays reserved for Phase 6 embeddings.
-- Catalog name MUST be 032_sender_profile_signature_html.

update public.sender_profile
set signature_block = $sig$<div style="margin-top:24px;padding-top:16px;border-top:1px solid #c8c8c8;font-family:Georgia,serif;color:#222;line-height:1.5;font-size:14px;">
  <div style="font-size:16px;font-weight:600;"><OWNER_NAME></div>
  <div style="margin-top:10px;">Building SilaCares - caring for loved ones from a distance,<br>through technology. silacares.com</div>
  <div style="margin-top:10px;">Building Ionicx.io - AI-driven architecture and services.<br>We automate the work: lower cost, faster processes,<br>more revenue.</div>
  <div style="margin-top:10px;">Twenty years in IT, networks and communications - now<br>putting it into my own products.</div>
  <div style="margin-top:10px;"><a href="https://linkedin.com/in/talal-baig">linkedin.com/in/talal-baig</a></div>
</div>$sig$,
    updated_at = now()
where owner_id = (
  select e.owner_id from public.events e where e.name = 'LEAP 2026' limit 1
);
