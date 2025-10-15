# A Ruby static code analyzer and formatter, based on the community
# Ruby style guide. https://docs.rubocop.org
gem "rubocop", require: false
file ".rubocop.yml", <<~CODE
  AllCops:
    NewCops: enable
    Exclude:
      - bin/*
      - db/migrate/*.rb
      - db/schema.rb
      - Gemfile
      - config.ru
      - Rakefile

  Layout/FirstArgumentIndentation:
    EnforcedStyle: special_for_inner_method_call_in_parentheses

  Layout/FirstHashElementIndentation:
    EnforcedStyle: special_inside_parentheses

  Layout/HashAlignment:
    Enabled: true
    EnforcedHashRocketStyle: table
    EnforcedColonStyle: table

  Layout/MultilineMethodCallIndentation:
    EnforcedStyle: indented_relative_to_receiver

  Layout/LineLength:
    Enabled: false

  Lint/ConstantDefinitionInBlock:
    Enabled: false

  Lint/DuplicateBranch:
    Enabled: false

  Lint/EmptyBlock:
    Enabled: false

  Lint/RaiseException:
    Enabled: true

  Lint/StructNewOverride:
    Enabled: true

  Lint/RescueException:
    Enabled: false

  Metrics/AbcSize:
    Enabled: false

  Metrics/BlockLength:
    Enabled: false

  Metrics/BlockNesting:
    Enabled: false

  Metrics/ClassLength:
    Enabled: false

  Metrics/CyclomaticComplexity:
    Enabled: false

  Metrics/MethodLength:
    Enabled: false

  Metrics/ModuleLength:
    Enabled: false

  Metrics/ParameterLists:
    Enabled: false

  Metrics/PerceivedComplexity:
    Enabled: false

  Naming/AccessorMethodName:
    Enabled: false

  Naming/MethodParameterName:
    AllowNamesEndingInNumbers: true
    MinNameLength: 1

  Naming/PredicatePrefix:
    Enabled: false

  Naming/VariableNumber:
    Enabled: false

  Style/AsciiComments:
    Enabled: false

  Style/ClassAndModuleChildren:
    Enabled: false

  Style/CombinableLoops:
    Enabled: false

  Style/ConditionalAssignment:
    EnforcedStyle: assign_inside_condition
    IncludeTernaryExpressions: false

  Style/Documentation:
    Enabled: false

  Style/EmptyMethod:
    EnforcedStyle: expanded

  Style/FrozenStringLiteralComment:
    Enabled: false

  Style/GuardClause:
    Enabled: false

  Style/HashEachMethods:
    Enabled: false

  Style/HashLikeCase:
    Enabled: false

  Style/HashSyntax:
    EnforcedShorthandSyntax: never

  Style/HashTransformKeys:
    Enabled: false

  Style/HashTransformValues:
    Enabled: false

  Style/IfInsideElse:
    Enabled: false

  Style/IfUnlessModifier:
    Enabled: false

  Style/MinMaxComparison:
    Enabled: false

  Style/NegatedIf:
    Enabled: false

  Style/Next:
    Enabled: false

  Style/NumericLiterals:
    Enabled: false

  Style/NumericPredicate:
    Enabled: false

  Style/RedundantReturn:
    Enabled: false

  Style/RegexpLiteral:
    EnforcedStyle: slashes
    AllowInnerSlashes: true

  Style/RescueStandardError:
    Enabled: false

  Style/SoleNestedConditional:
    Enabled: false

  Style/StringConcatenation:
    Enabled: false

  Style/StringLiterals:
    ConsistentQuotesInMultiline: true
    EnforcedStyle: double_quotes

  Style/SymbolArray:
    EnforcedStyle: brackets

  Style/WordArray:
    EnforcedStyle: brackets

  Style/YodaCondition:
    Enabled: false

  Style/ZeroLengthPredicate:
    Enabled: false
CODE
