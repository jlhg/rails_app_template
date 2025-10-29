require "yaml"
require "psych"

def root_path
  File.dirname(__dir__)
end

def recipe_path
  File.join(root_path, "recipe")
end

def files_path
  File.join(root_path, "template", "files")
end

def eval_file_content(file_path)
  eval File.read(file_path)
end

def recipe(name)
  eval_file_content File.join(recipe_path, "#{name}.rb")
end

def from_files(path)
  File.join(files_path, path)
end

def update_yaml(file_path, data)
  yaml = Psych.load_file(file_path) || {}
  yaml.update(data)
  ast = Psych.parse_stream yaml.to_yaml
  ast.grep(Psych::Nodes::Scalar).each do |node|
    node.plain = true
    node.quoted = false
    node.style  = Psych::Nodes::Scalar::ANY
  end
  File.write(file_path, ast.yaml)
end
