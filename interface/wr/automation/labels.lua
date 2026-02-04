function timeScale(time)
	local timeLabel = "Per Second"
	local multiplier = 1
	if time == 0 then
	elseif (time * multiplier) < 0.1 then
		timeLabel = "Per Minute"
		multiplier = multiplier * 60
		if (time * multiplier) < 0.1 then
			timeLabel = "Per Hour"
			multiplier = multiplier * 60
			if (time * multiplier) < 0.1 then
				timeLabel = "Per Day"
				multiplier = multiplier * 24
				if (time * multiplier) < 0.1 then
					timeLabel = "Per Week"
					multiplier = multiplier * 7
				end
			end
		end
	end
	return multiplier, timeLabel
end

function clipAtThousandth(n)
	if n == 0 then return "0" end
	if n < 0.001 then
		return "< 0.001"
	end
	return tostring(math.floor(n * 1000) / 1000)
end
