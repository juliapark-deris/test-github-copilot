---
name: stepwise-implementation-check
description: "Use when: implementing features step by step, one step at a time, then reporting what changed on screen first, waiting for user verification, and if it fails, splitting expected vs actual behavior. Korean triggers: 한 번에 한 단계씩, 화면에서 뭐가 달라졌는지 먼저, 내가 직접 확인, 기대한 것과 실제 일어난 것."
user-invocable: true
---

# Stepwise Implementation Check

## Purpose
이 스킬은 초보자 학습 흐름에 맞춰, 기능 구현을 작은 단위로 진행하고 매 단계 검증을 강제하는 작업 절차를 정의한다.

## Workflow Rules (Must Follow)
1. 한 번에 한 단계만 구현한다.
2. 구현이 끝나면 코드 설명보다 먼저 "화면에서 달라진 점"을 말한다.
3. 사용자 확인 전에는 다음 단계를 진행하지 않는다.
4. 동작이 기대와 다르면 반드시 아래 형식으로 정리한다.
   - 기대한 것(Expected)
   - 실제 일어난 것(Actual)
5. Expected vs Actual이 정리되면 원인 가설 1~2개를 제시하고, 가장 작은 수정 1개만 적용한다.
6. 수정 후 다시 화면 변화 -> 사용자 확인 순서를 반복한다.

## Response Template
### After each implementation step
- 이번 단계에서 바꾼 것:
- 화면에서 달라진 점:
- 확인 요청: "지금 화면에서 이 변화가 보이나요?"

### If user says it does not work
- 기대한 것(Expected):
- 실제 일어난 것(Actual):
- 가장 가능성 높은 원인:
- 다음 최소 수정 1개:

## Guardrails
- 한 응답에서 여러 기능을 동시에 구현하지 않는다.
- 사용자가 확인하기 전에는 다음 TODO를 시작하지 않는다.
- 전문 용어가 나오면 괄호로 짧게 뜻을 붙인다.
- 설명은 짧고 쉬운 한국어를 우선한다.

## Done Criteria per Step
- 코드 변경 완료
- 화면 변화 설명 완료
- 사용자 확인 완료

다음 단계로 넘어가는 조건: 위 3개가 모두 충족되었을 때만.
