
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.verified_fd_rates, public.current_user_role
  FROM anon, authenticated;
