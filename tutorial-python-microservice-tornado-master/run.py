#!/usr/bin/env python

import argparse
import os
import subprocess
from typing import List
import unittest

SOURCE_CODE = ['addrservice']
TEST_CODE = ['tests']
ALL_CODE = SOURCE_CODE + TEST_CODE


def arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description='Exécuter le linter, le vérificateur de type statique et les tests'
    )

    subparsers = parser.add_subparsers(dest='func', help='sous-commandes')

    typechecker_cmd_parser = subparsers.add_parser('typecheck', help='Vérification de type')
    typechecker_cmd_parser.add_argument(
        '-c', '--checker',
        default='mypy',
        help='spécifier le vérificateur de type statique, défaut : %(default)s'
    )
    typechecker_cmd_parser.add_argument(
        'paths',
        nargs='*',
        default=ALL_CODE,
        help='répertoires et fichiers à vérifier'
    )

    lint_cmd_parser = subparsers.add_parser('lint', help='Linting du code')
    lint_cmd_parser.add_argument(
        '-l', '--linter',
        default='flake8',
        help='spécifier le linter, défaut : %(default)s'
    )
    lint_cmd_parser.add_argument(
        'paths',
        nargs='*',
        default=ALL_CODE,
        help='répertoires et fichiers à vérifier'
    )

    test_cmd_parser = subparsers.add_parser('test', help='Exécution des tests')
    test_cmd_parser.add_argument(
        '--suite',
        choices=['all', 'unit', 'integration'],
        default='all',
        type=str,
        help='suite de tests à exécuter, défaut : %(default)s'
    )
    test_cmd_parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='activer la sortie détaillée'
    )

    return parser


def run_checker(checker: str, paths: List[str]) -> None:
    if len(paths) != 0:
        subprocess.call([checker] + paths)


def run_tests(suite_name: str, verbose: bool) -> None:
    test_suites = {
        'all': 'tests',
        'unit': 'tests/unit',
        'integration': 'tests/integration'
    }
    suite = test_suites.get(suite_name, 'tests')

    verbosity = 2 if verbose else 1

    test_suite = unittest.TestLoader().discover(suite, pattern='*_test.py')
    unittest.TextTestRunner(verbosity=verbosity).run(test_suite)


def main(args=None) -> None:
    os.chdir(os.path.abspath(os.path.dirname(__file__)))

    parser = arg_parser()
    args = parser.parse_args(args)
    # print(args)

    actions = {
        'typecheck': lambda: run_checker(args.checker, args.paths),
        'lint': lambda: run_checker(args.linter, args.paths),
        'test': lambda: run_tests(args.suite, args.verbose),
    }

    actions.get(args.func, parser.print_help)()


if __name__ == "__main__":
    main()
