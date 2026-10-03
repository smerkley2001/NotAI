-- Image quotas count every reserved attempt, including failures, to bound provider spend.
create index if not exists ai_requests_image_created_at on notai_private.ai_requests(created_at) where model like 'image:%';
create function notai_private.reserve_image(p_key uuid) returns void language plpgsql security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile();begin
 if owner_id is null then raise exception 'Complete your account profile first';end if;
 perform pg_advisory_xact_lock(hashtextextended('notai-image-global',4));
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,4));
 if (select count(*) from notai_private.ai_requests where user_id=owner_id and model like 'image:%' and created_at>now()-interval '24 hours')>=3 then raise exception 'Image allowance reached';end if;
 if (select count(*) from notai_private.ai_requests where model like 'image:%' and created_at>now()-interval '1 hour')>=30 then raise exception 'Image previews busy';end if;
 insert into notai_private.ai_requests(id,user_id,model) values(p_key,owner_id,'image:reserved');
end $$;
revoke all on function notai_private.reserve_image(uuid) from public,anon;grant execute on function notai_private.reserve_image(uuid) to authenticated;
create function public.reserve_image(p_key uuid) returns void language sql security invoker set search_path='' as $$select notai_private.reserve_image(p_key);$$;
revoke all on function public.reserve_image(uuid) from public,anon;grant execute on function public.reserve_image(uuid) to authenticated;
-- Completion metadata is owner scoped and never used to grant credits, quotas or access.
create function notai_private.finish_image(p_key uuid,p_completed boolean) returns void language sql security definer set search_path='' as $$
 update notai_private.ai_requests set status=case when p_completed then 'completed' else 'failed' end
 where id=p_key and user_id=notai_private.current_profile() and model='image:reserved' and status='reserved';
$$;
revoke all on function notai_private.finish_image(uuid,boolean) from public,anon;grant execute on function notai_private.finish_image(uuid,boolean) to authenticated;
create function public.finish_image(p_key uuid,p_completed boolean) returns void language sql security invoker set search_path='' as $$select notai_private.finish_image(p_key,p_completed);$$;
revoke all on function public.finish_image(uuid,boolean) from public,anon;grant execute on function public.finish_image(uuid,boolean) to authenticated;
