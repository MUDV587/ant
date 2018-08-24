return function(file_path, ...)
   if RUN_FUNC_NAME == file_path then
       pcall(RUN_FUNC, ...)
       return
   end

   local f, hash = client_repo:open(file_path)
   if not f then
       assert(false, "cannot find file: " .. file_path)
   end

   local content = f:read("a")
   f:close()
   local run_func = load(content, "@" .. file_path)
   local err, result = pcall(run_func, ...)
   if not err then
       print("run file "..file_path.." error: " .. tostring(result))
       return nil
   end

   RUN_FUNC_NAME = file_path
   RUN_FUNC = result
   pcall(RUN_FUNC, ...)
end