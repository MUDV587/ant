--[[
	cd to ant path, run:
	clibs/lua.exe tools/repo/newrepo.lua *projname* [*editor*]

	editor is optional
]]
dofile "libs/editor.lua"

local repopath = select(1, ...)

local repo = require "vfs.repo"
local lfs = require "filesystem.local"

local ANTGE = os.getenv "ANTGE"
local enginepath = ANTGE and lfs.path(ANTGE) or lfs.current_path()

print ("Ant engine path :", enginepath)
if repopath == nil then
	error ("Need a project name")
end
print ("Project name :",repopath)

local mount = {
	["engine/libs"] = enginepath / "libs",
	["engine/assets"] = enginepath / "assets",
	["firmware"] = enginepath / "runtime" / "core" / "firmware",
}

if not lfs.is_directory(repopath) then
	if not lfs.create_directories(repopath) then
		error("Can't mkdir ", repopath)
	end
end

local engine_mountpoint = repopath / "engine"
if not lfs.is_directory(engine_mountpoint) then
	print("Mkdir ", engine_mountpoint)
	assert(lfs.create_directories(engine_mountpoint))
end

mount[1] = repopath

print("Init repo in", repopath)
repo.init(mount)
