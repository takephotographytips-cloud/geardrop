create policy "Allow anonymous inserts for automated script" 
on public.articles 
for insert 
with check (true);
