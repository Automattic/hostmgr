.DEFAULT_GOAL := lint

lint:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.47.1 swiftlint lint --strict

lintfix:
	docker run -it --rm -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.47.1 swiftlint --autocorrect
