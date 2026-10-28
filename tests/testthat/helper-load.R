# helper-load.R ---- the project is a compendium, not a package: source the function library.
root <- project_root_for_tests <- (function() { d <- normalizePath(testthat::test_path("..", "..")); d })()
for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) source(f)
