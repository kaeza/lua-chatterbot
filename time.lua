
local require, pcall, print =
      require, pcall, print

module "time"

local ok, ffi = pcall(require, "ffi")

if ok then
	ffi.cdef [[
		int sched_yield(void);
		int sleep(int sec);
		int usleep(int usec);
	]]
	print("Using FFI")
	sched_yield = ffi.C.sched_yield
	sleep = ffi.C.sleep
	usleep = ffi.C.usleep
else
	print("FFI not available")
	function sched_yield() end
	function sleep() end
	function usleep() end
end
