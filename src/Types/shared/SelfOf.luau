--!strict
-- Monta o `self` de um modulo: enxerta `Dependencies` sobre os metodos da
-- folha e reaponta o primeiro parametro de cada metodo para a tabela em
-- construcao. A recursao fecha aqui dentro, pelo handle mutavel do
-- `types.newtable()` — nao precisa de alias recursivo nem de parametro
-- generico atravessando o Manifest.
--
-- Duas tabelas de proposito:
--   inner  o que o `self` enxerga — metodos read-only, para casar com a visao
--          que o solver infere de um parametro nao anotado
--   outer  o alvo de atribuicao — metodos gravaveis
-- Com uma tabela so, ate o corpo correto falha por invariancia:
--   `(t2) -> ()` versus `(t1) -> (...unknown)`.
export type function Build(leaf: type, deps: type): type
	if not leaf:is("table") then
		error(`[SelfOf] leaf deve ser table, recebi {leaf.tag}`)
	end
	if not deps:is("table") then
		error(`[SelfOf] deps deve ser table, recebi {deps.tag}`)
	end

	local inner = types.newtable()
	local outer = types.newtable()
	inner:setreadproperty(types.singleton("Dependencies"), deps)
	outer:setreadproperty(types.singleton("Dependencies"), deps)

	for key, prop in leaf:properties() do
		local t = prop.read or prop.write
		if t and t:is("function") then
			local f = types.copy(t)
			local p = f:parameters()
			-- `{ inner }` mais `table.insert` nao compila: invariancia de array
			-- na assinatura de `setparameters`. Clonar e sobrescrever funciona.
			local head = if p.head then table.clone(p.head) else {}
			if #head > 0 then
				head[1] = inner
			end
			f:setparameters(head, p.tail)
			inner:setreadproperty(key, f)
			outer:setproperty(key, f)
		elseif t then
			inner:setreadproperty(key, t)
			outer:setproperty(key, t)
		end
	end

	return outer
end

return {}
