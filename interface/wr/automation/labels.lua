function timeScale(time)
	local timeLabel = "Per Second"
	local multiplier = 1
	if time == 0 then
	elseif (time * multiplier) >= 1000 then
		timeLabel = "Per Millisecond"
		multiplier = multiplier / 1000
	elseif (time * multiplier) <= 0.1 then
		timeLabel = "Per Minute"
		multiplier = multiplier * 60
		if (time * multiplier) <= 0.1 then
			timeLabel = "Per Hour"
			multiplier = multiplier * 60
			if (time * multiplier) <= 0.1 then
				timeLabel = "Per Day"
				multiplier = multiplier * 24
				if (time * multiplier) <= 0.1 then
					timeLabel = "Per Week"
					multiplier = multiplier * 7
					if time * multiplier <= 0.1 then
						timeLabel = "Per Year"
						multiplier = multiplier * 52.14285714285714
					end
				end
			end
		end
	end
	return multiplier, timeLabel
end

function durationLabel(time)
	local timeDivisor = 1
	local timeLabel	= "Seconds"
	local compTime = time
	if time == 1 then
		timeLabel = "Second"
	elseif compTime >= 60 then
		timeLabel = "Minutes"
		timeDivisor = timeDivisor * 60
		compTime = time / timeDivisor
		if compTime == 1 then
			timeLabel = "Minute"
		elseif compTime >= 60 then
			timeLabel = "Hours"
			timeDivisor = timeDivisor * 60
			compTime = time / timeDivisor
			if compTime == 1 then
				timeLabel = "Hour"
			elseif compTime >= 24 then
				timeLabel = "Days"
				timeDivisor = timeDivisor * 24
				compTime = time / timeDivisor
				if compTime == 1 then
					timeLabel = "Day"
				elseif compTime >= 365 then
					timeLabel = "Years"
					timeDivisor = timeDivisor * 365
					compTime = time / timeDivisor
					if compTime == 1 then
						timeLabel = "Year"
					end
				elseif compTime >= 7 then
					timeLabel = "Weeks"
					timeDivisor = timeDivisor * 7
					compTime = time / timeDivisor
					if compTime == 1 then
						timeLabel = "Week"
					end
				end
			end
		end
	end
	return timeDivisor, timeLabel
end

function clipAtThousandth(n)
	if n == 0 then return "0" end
	if n < 0.001 then
		return "< 0.001"
	end
    local printNumber = math.floor(n * 1000) / 1000
    local floored = math.floor(printNumber)
	if floored == printNumber then
		return ("%s"):format(floored)
	end
	return ("%s"):format(printNumber)
end
