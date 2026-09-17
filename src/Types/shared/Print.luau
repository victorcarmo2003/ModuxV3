export type function Table(t: type)
	if not t:is("table") then
		error(`SHOW: nao e table, tag={t.tag}`)
	end
	local names = {}
	for k in t:properties() do
		table.insert(names, tostring(k:value()))
	end
	table.sort(names)
	local mt = t:metatable()
	error(`SHOW props=[{table.concat(names, ",")}] metatable={mt and "sim" or "nao"}`)
end

return {}
