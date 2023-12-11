local function copy_to_clipboard(text)
  vim.fn.setreg("+", text)
end

local function open_url_in_browser(url)
  -- Comando específico para abrir una URL en el navegador (puedes ajustarlo según tu sistema operativo)
  local command = string.format("xdg-open %s", url) -- Comando para Linux (usando xdg-open)

  -- Ejecutar el comando en el sistema operativo
  vim.fn.jobstart(command, {
    detach = true,
    cwd = vim.fn.getcwd(),
  })
end

local function get_remote_url()
  local remote_url = vim.fn.trim(vim.fn.system("git config --get remote.origin.url"))

  -- Si la URL es de tipo ssh, realiza la transformación basada en las definiciones de ~/.gitconfig
  if remote_url:match("^ssh://") then
    -- Extraer el dominio de la URL ssh
    local domain = remote_url:match("ssh://([^/]+)")

    -- Buscar definiciones en ~/.gitconfig para el dominio específico
    local gitconfig_url = vim.fn.trim(vim.fn.system("git config --get-urlmatch url.insteadof ssh://" .. domain))

    -- Si se encontró una definición en ~/.gitconfig, transformar la URL
    if gitconfig_url ~= "" then
      -- Extraer la parte del repositorio desde la raíz del dominio hasta .git
      local repo_path = remote_url:match(domain .. "/(.+)%.git$")
      if repo_path then
        return gitconfig_url:gsub("%.git$", "") .. repo_path -- Construir la URL transformada
      end
    end
  end

  -- Si no se realiza ninguna transformación, aplicar la conversión de URL según el patrón
  local https_url =
    remote_url:gsub("git@([^:]+):", "https://%1/"):gsub("ssh://git@([^:/]+)/", "https://%1/"):gsub("%.git$", "")

  return https_url
end

local function get_current_line_url()
  local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
  local filename = vim.fn.expand("%:p"):gsub("^" .. git_root .. "/", "")
  local linenr = vim.api.nvim_win_get_cursor(0)[1]

  local relative_filename = vim.fn.trim(vim.fn.system("git ls-files --full-name " .. filename))
  local remote_url = get_remote_url()

  if remote_url then
    return string.format("%s/blob/master/%s#L%d", remote_url, relative_filename, linenr)
  end
end

local function copy_line_url()
  local remote_url = get_current_line_url()
  if remote_url then
    copy_to_clipboard(remote_url)
  end
end

local function open_line_url()
  local remote_url = get_current_line_url()
  if remote_url then
    open_url_in_browser(remote_url)
  end
end

return {
  copy_line_url = copy_line_url,
  open_line_url = open_line_url,
}
