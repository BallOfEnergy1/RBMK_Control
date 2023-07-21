

local gpulib = {}
-- GPU library

function gpulib.createBuffer(width, height)
	return require("component").gpu.allocateBuffer(width, height)
end
function gpulib.removeBuffer(index)
	return require("component").gpu.freeBuffer(index)
end
function gpulib.getBuffers()
	return require("component").gpu.buffers()
end
function gpulib.getBufferSize(bufferIndex)
	return require("component").gpu.bufferSize(bufferIndex)
end
function gpulib.VRAM_state()
	local memoryState = {}
	memoryState[1] = require("component").gpu.freeMemory()
	memoryState[2] = require("component").gpu.totalMemory()
	memoryState[3] = memoryState[2] - memoryState[1]
	return memoryState
end
function gpulib.clear()
	return require("component").gpu.freeAllBuffers()
end
function gpulib.readPixel(x, y, bufferIndex)
	local prev_buffer = require("component").gpu.getActiveBuffer()
	require("component").gpu.setActiveBuffer(bufferIndex)
	local pixelData = {}
	pixelData[1], pixelData[2], pixelData[3] = require("component").gpu.get(x, y)
	require("component").gpu.setActiveBuffer(prev_buffer)
	return pixelData
end
function gpulib.writeData(dataData, bufferIndex)
	local prev_buffer = require("component").gpu.getActiveBuffer()
	require("component").gpu.setActiveBuffer(bufferIndex)
	require("component").gpu.set(dataData[1], dataData[2], dataData[3])
	require("component").gpu.setActiveBuffer(prev_buffer)
end
function gpulib.writeArea(areaData, bufferIndex)
	local prev_buffer = require("component").gpu.getActiveBuffer()
	require("component").gpu.setActiveBuffer(bufferIndex)
	require("component").gpu.fill(areaData[1], areaData[2], areaData[3], areaData[4], areaData[5])
	require("component").gpu.setActiveBuffer(prev_buffer)
end
function gpulib.bitblt(destBuffer, fromBuffer, width, height, Dx, Dy, Fx, Fy)
	require("component").gpu.bitblt(destBuffer, Dx, Dy, width, height, fromBuffer, Fx, Fy)
end

return gpulib