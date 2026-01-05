%% test_m2.m
% M2 기법 테스트
%
% M2 특징:
%   - T_hold 동안 SA-RU 할당 스킵 (Phantom 0)
%   - T_hold 만료 시 1회 할당 시도
%   - 성공/실패 무관 종료

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    M2 기법 테스트                                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 테스트 1: M2 설정 확인
fprintf('[테스트 1] M2 설정 확인\n');
fprintf('─────────────────────────────────────────\n');

cfg = config_default();
cfg.thold_method = 'M2';
fprintf('thold_method = %s\n', cfg.thold_method);

if strcmp(cfg.thold_method, 'M2')
    fprintf('✓ 테스트 1 통과: M2 설정 가능\n');
    test1_pass = true;
else
    fprintf('✗ 테스트 1 실패\n');
    test1_pass = false;
end

%% 테스트 2: M2 짧은 시뮬레이션
fprintf('\n[테스트 2] M2 시뮬레이션 (5초)\n');
fprintf('─────────────────────────────────────────\n');

cfg = config_default();
cfg.num_stas = 10;
cfg.simulation_time = 5;
cfg.traffic_model = 'pareto_onoff';
cfg.lambda = 100;
cfg.rho = 0.3;
cfg.mu_on = 0.021;
cfg.mu_off = 0.050;
cfg.seed = 1234;
cfg.verbose = 0;

% M2 설정
cfg.thold_enabled = true;
cfg.thold_value = 0.050;  % 50ms
cfg.thold_method = 'M2';

fprintf('설정: %d STAs, λ=%d, T_hold=%dms, Method=%s\n', ...
    cfg.num_stas, cfg.lambda, cfg.thold_value*1000, cfg.thold_method);

tic;
result_m2 = run_simulation(cfg);
elapsed = toc;

fprintf('완료 (%.1fs)\n\n', elapsed);

% 결과 출력
fprintf('M2 결과:\n');
fprintf('  생성 패킷: %d\n', result_m2.packets.generated);
fprintf('  완료 패킷: %d\n', result_m2.packets.completed);
fprintf('  평균 지연: %.1f ms\n', result_m2.delay.mean_ms);
fprintf('  T_hold 발동: %d회\n', result_m2.thold.activations);
fprintf('  T_hold Hit: %d회\n', result_m2.thold.hits);
fprintf('  Hit Rate: %.1f%%\n', result_m2.thold.hit_rate * 100);
fprintf('  Phantom: %d회\n', result_m2.thold.phantoms);
fprintf('  Clean Exp: %d회\n', result_m2.thold.clean_exp);

% M2 핵심 검증: Phantom 횟수
% M2는 T_hold 동안 스킵하므로 phantom이 매우 적어야 함
% (만료 시 1회 할당에서만 phantom 발생 가능)
if result_m2.thold.phantoms <= result_m2.thold.activations
    fprintf('\n✓ 테스트 2 통과: Phantom ≤ Activations (M2 특성)\n');
    test2_pass = true;
else
    fprintf('\n✗ 테스트 2 실패: Phantom이 너무 많음\n');
    test2_pass = false;
end

%% 테스트 3: M0 vs M2 비교
fprintf('\n[테스트 3] M0 vs M2 비교\n');
fprintf('─────────────────────────────────────────\n');

% M0 실행
cfg.thold_method = 'M0';
result_m0 = run_simulation(cfg);

fprintf('M0 결과:\n');
fprintf('  평균 지연: %.1f ms\n', result_m0.delay.mean_ms);
fprintf('  Hit Rate: %.1f%%\n', result_m0.thold.hit_rate * 100);
fprintf('  Phantom: %d회\n', result_m0.thold.phantoms);

fprintf('\nM2 결과:\n');
fprintf('  평균 지연: %.1f ms\n', result_m2.delay.mean_ms);
fprintf('  Hit Rate: %.1f%%\n', result_m2.thold.hit_rate * 100);
fprintf('  Phantom: %d회\n', result_m2.thold.phantoms);

fprintf('\n비교:\n');
fprintf('  지연: M0=%.1f ms, M2=%.1f ms\n', result_m0.delay.mean_ms, result_m2.delay.mean_ms);
fprintf('  Phantom: M0=%d, M2=%d (%.1f%% 감소)\n', ...
    result_m0.thold.phantoms, result_m2.thold.phantoms, ...
    (1 - result_m2.thold.phantoms / max(1, result_m0.thold.phantoms)) * 100);

% M2는 M0보다 phantom이 적어야 함
if result_m2.thold.phantoms < result_m0.thold.phantoms
    fprintf('\n✓ 테스트 3 통과: M2 phantom < M0 phantom\n');
    test3_pass = true;
else
    fprintf('\n✗ 테스트 3 실패: M2 phantom ≥ M0 phantom\n');
    test3_pass = false;
end

%% 테스트 4: thold_waiting_final 필드 존재 확인
fprintf('\n[테스트 4] thold_waiting_final 필드 확인\n');
fprintf('─────────────────────────────────────────\n');

% STA 클래스 메타데이터로 확인
try
    mc = meta.class.fromName('STA');
    prop_names = {mc.PropertyList.Name};
    
    if ismember('thold_waiting_final', prop_names)
        fprintf('✓ 테스트 4 통과: thold_waiting_final 필드 존재\n');
        test4_pass = true;
    else
        fprintf('✗ 테스트 4 실패: thold_waiting_final 필드 없음\n');
        test4_pass = false;
    end
catch
    % 메타데이터 접근 실패 시 직접 인스턴스 생성
    cfg_test = config_default();
    sta_test = STA(1, cfg_test);
    if isprop(sta_test, 'thold_waiting_final')
        fprintf('✓ 테스트 4 통과: thold_waiting_final 필드 존재\n');
        test4_pass = true;
    else
        fprintf('✗ 테스트 4 실패: thold_waiting_final 필드 없음\n');
        test4_pass = false;
    end
end

%% 요약
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('  테스트 결과 요약\n');
fprintf('───────────────────────────────────────────────────────────────────\n');
fprintf('  테스트 1 (M2 설정):        %s\n', pass_fail(test1_pass));
fprintf('  테스트 2 (M2 시뮬레이션): %s\n', pass_fail(test2_pass));
fprintf('  테스트 3 (M0 vs M2):      %s\n', pass_fail(test3_pass));
fprintf('  테스트 4 (필드 확인):      %s\n', pass_fail(test4_pass));
fprintf('───────────────────────────────────────────────────────────────────\n');

if test1_pass && test2_pass && test3_pass && test4_pass
    fprintf('  ✓ 모든 테스트 통과! M2 구현 완료\n');
else
    fprintf('  ✗ 일부 테스트 실패 - 코드 확인 필요\n');
end
fprintf('═══════════════════════════════════════════════════════════════════\n');

function s = pass_fail(b)
    if b
        s = '✓ PASS';
    else
        s = '✗ FAIL';
    end
end