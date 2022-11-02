.DEFAULT_GOAL := lint

lint:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.49.1 swiftlint lint --strict --progress

lintfix:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.49.1 swiftlint --fix
