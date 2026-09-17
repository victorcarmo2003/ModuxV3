--!strict
-- Monta o `self` de um modulo: enxerta `Dependencies` sobre os membros da
-- folha e reaponta o primeiro parametro dos METODOS para a tabela em
-- construcao. A recursao fecha aqui dentro, pelo handle mutavel do
-- `types.newtable()` — nao precisa de alias recursivo nem de parametro
-- generico atravessando o Manifest.
--
-- Duas tabelas de proposito:
--   inner  o que o `self` enxerga dentro dos metodos e dos callbacks
--   outer  o alvo de atribuicao, na saida da fabrica
--
-- A distincao entre metodo e campo importa:
--   metodo (`Heal: (self: Public, n: number) -> ()`) ganha o reaponte de self
--          e fica read-only no inner. O read-only e o que faz o corpo correto
--          passar: sem ele a propriedade e invariante e o `self` inferido do
--          lambda (visao read, cauda `...unknown`) nao casa.
--   campo  (`Apple: string`, ou `Source: (n: number) -> string` guardado num
--          campo) fica gravavel e intocado. Reapontar o primeiro parametro de
--          um campo de funcao destroi a assinatura dele.
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
		local t: type? = prop.read or prop.write
		if t ~= nil then
			local tt: type = t
			local metodo = false
			local head: { type } = {}
			if tt:is("function") then
				local p = tt:parameters()
				-- `{ inner }` mais `table.insert` nao compila: invariancia de
				-- array na assinatura de `setparameters`. Clonar funciona.
				head = if p.head then table.clone(p.head) else {}
				-- METODO e aquele cujo primeiro parametro E a propria folha.
				-- Userdata compara por referencia, que e a pergunta certa aqui.
				metodo = #head > 0 and head[1] == leaf
			end

			if metodo then
				local f = types.copy(tt)
				head[1] = inner
				f:setparameters(head, tt:parameters().tail)
				inner:setreadproperty(key, f)
				outer:setproperty(key, f)
			else
				inner:setproperty(key, tt)
				outer:setproperty(key, tt)
			end
		end
	end

	return outer
end

-- NAO REMOVER. O luau-lsp so avalia uma type function exportada se ela for
-- instanciada ao menos uma vez NO ARQUIVO QUE A DEFINE. Sem esta linha, todo
-- `SelfOf.Build<...>` de fora vira `*error-type*` no editor — some hover e
-- autocomplete — enquanto o luau-analyze passa limpo. Foi assim que o Pick e o
-- Occlude sempre funcionaram: os dois instanciam no proprio arquivo.
type _FolhaExemplo = {
	Campo: number,
	Metodo: (self: _FolhaExemplo, n: number) -> (),
}
type _forcaAvaliacao = Build<_FolhaExemplo, {}>

return {}
