"""A small client for `voxelith --mcp` (no dependencies): spawns the engine and speaks the Model Context Protocol to it over pipes.

    from voxelith_client import Voxelith
    with Voxelith(["--project", "projects/demo_level"]) as v:
        print(v.status()["player"])
        v.lua("edit.sphere(1500, 600, 1900, 12, 'brick')")
        v.run_script("turn:90,boom:40,idle:120")
        v.screenshot("shot.png", time_of_day=0.25)
        print(v.state_hash())
"""
import base64, collections, json, os, subprocess, threading

DEFAULT_BIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "release", "voxelith")


class McpError(RuntimeError):
    pass


class Voxelith:
    def __init__(self, args=(), binary=None, env=None):
        self.binary = binary or os.environ.get("VOXELITH", DEFAULT_BIN)
        self.p = subprocess.Popen([self.binary, "--mcp"] + list(args), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace", bufsize=1,
                                  env=dict(os.environ, **(env or {})))
        # the engine logs to stderr: it is drained all the time (a full pipe would block the server in the middle of a call); the last lines are kept for error messages
        self._err = collections.deque(maxlen=200)
        threading.Thread(target=lambda: [self._err.append(l) for l in self.p.stderr], daemon=True).start()
        self._id = 0
        init = self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "voxelith_client.py", "version": "1"}})
        if "result" not in init:
            raise McpError("initialize failed: %r" % (init,))
        self.info = init["result"]
        self.rpc("notifications/initialized", notify=True)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def rpc(self, method, params=None, notify=False):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        if not notify:
            self._id += 1
            msg["id"] = self._id
        self.p.stdin.write(json.dumps(msg) + "\n")
        self.p.stdin.flush()
        if notify:
            return None
        line = self.p.stdout.readline()
        if not line:
            raise McpError("the server closed: " + "".join(self._err)[-2000:])
        return json.loads(line)

    def call(self, tool_name, /, **args):
        """The raw result of a tool call: {content, isError, structuredContent?}."""
        reply = self.rpc("tools/call", {"name": tool_name, "arguments": args})
        if "error" in reply:
            raise McpError(reply["error"]["message"])
        return reply["result"]

    def tool(self, tool_name, /, **args):
        """The structured result of a tool call (or its text); raises McpError when the tool reports an error."""
        r = self.call(tool_name, **args)
        if r.get("isError"):
            raise McpError((r.get("structuredContent") or {}).get("error") or r["content"][0]["text"])
        return r.get("structuredContent") if r.get("structuredContent") is not None else r["content"][0]["text"]

    def stderr_tail(self, lines=40):
        return "".join(list(self._err)[-lines:])

    # the tools
    def status(self): return self.tool("status")
    def step(self, ticks=60): return self.tool("step", ticks=ticks)
    def run_script(self, script, max_ticks=None): return self.tool("run_script", script=script, **({"max_ticks": max_ticks} if max_ticks else {}))
    def lua(self, code, ticks=1): return self.tool("lua", code=code, ticks=ticks)
    def raycast(self, **kw): return self.tool("raycast", **kw)
    def query_voxels(self, points, units="voxels"): return self.tool("query_voxels", points=points, units=units)["voxels"]
    def describe(self): return self.tool("describe")
    def count_voxels(self, lo, hi, material=None): return self.tool("count_voxels", min=lo, max=hi, **({"material": material} if material else {}))
    def slice(self, axis, at, lo, hi, step=1): return self.call("slice", axis=axis, at=at, min=lo, max=hi, step=step)["content"][0]["text"]
    def step_until(self, condition, max_ticks=3600, tick=None): return self.tool("step_until", condition=condition, max_ticks=max_ticks, **({"tick": tick} if tick is not None else {}))
    def look_from(self, eye, target, mode="walk"): return self.tool("look_from", eye=eye, target=target, mode=mode)
    def bodies(self, limit=30): return self.tool("bodies", limit=limit)
    def gravity_fields(self): return self.tool("gravity_fields")
    def state_hash(self): return self.tool("state_hash")["hash"]
    def log(self, lines=40): return self.tool("log", lines=lines)
    def docs(self, topic): return self.tool("read_docs", topic=topic)
    def undo(self): return self.tool("undo")
    def redo(self): return self.tool("redo")
    def save_world(self): return self.tool("save_world")
    def new_project(self, dir, name=None): return self.call("new_project", dir=dir, **({} if name is None else {"name": name}))  # (a tool argument called `name` is fine: the tool name is positional-only)
    def find_material(self, material, near, radius=48, limit=10): return self.tool("find_material", material=material, near=near, radius=radius, limit=limit)  # near / radius in voxels
    def region_hash(self, lo, hi): return self.tool("region_hash", min=lo, max=hi)["hash"]  # voxel coordinates, inclusive
    def list_materials(self): return self.tool("list_materials")["materials"]
    def check_project(self, dir): return self.call("check_project", dir=dir)["content"][0]["text"]
    def verify_gpu(self, radius=12): return self.tool("verify_gpu", radius=radius)
    def particles(self, limit=30): return self.tool("particles", limit=limit)
    def reload_level(self, project=None): return self.call("reload_level", **({} if project is None else {"project": project}))  # the next call waits for the new world

    def screenshot(self, path=None, **kw):
        """Takes a screenshot; writes the PNG to `path` if given and returns the PNG bytes."""
        r = self.call("screenshot", **kw)
        if r.get("isError"):
            raise McpError(r["content"][0]["text"])
        png = base64.b64decode([c for c in r["content"] if c["type"] == "image"][0]["data"])
        if path:
            with open(path, "wb") as f:
                f.write(png)
        return png

    def close(self):
        try:
            self.p.stdin.close()
            self.p.wait(timeout=60)
        except Exception:
            self.p.kill()
