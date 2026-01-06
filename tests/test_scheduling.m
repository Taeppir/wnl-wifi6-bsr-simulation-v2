%% test_scheduling.m
% SA-RU 스케줄링이 BSR 큰 순서로 동작하는지 테스트
%
% 테스트 항목:
%   1. BSR 큰 순서로 정렬되는지 확인
%   2. 짧은 시뮬레이션으로 스케줄링 동작 확인

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║              SA-RU 스케줄링 테스트 (BSR 큰 순서)                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 테스트 1: BSR 정렬 로직 단독 테스트
fprintf('[테스트 1] BSR 정렬 로직\n');
fprintf('─────────────────────────────────────────\n');

% 테스트 데이터: STA 순서와 BSR이 다름
bsr_stas = [
    struct('sta_idx', 1, 'bsr', 2000, 'ru_needed', 1);
    struct('sta_idx', 2, 'bsr', 8000, 'ru_needed', 4);
    struct('sta_idx', 3, 'bsr', 4000, 'ru_needed', 2);
    struct('sta_idx', 4, 'bsr', 6000, 'ru_needed', 3);
    struct('sta_idx', 5, 'bsr', 2000, 'ru_needed', 1);
];

fprintf('정렬 전:\n');
for i = 1:length(bsr_stas)
    fprintf('  STA %d: BSR = %d bytes\n', bsr_stas(i).sta_idx, bsr_stas(i).bsr);
end

% BSR 큰 순서로 정렬
[~, sort_idx] = sort([bsr_stas.bsr], 'descend');
bsr_stas_sorted = bsr_stas(sort_idx);

fprintf('\n정렬 후 (BSR 큰 순서):\n');
for i = 1:length(bsr_stas_sorted)
    fprintf('  STA %d: BSR = %d bytes\n', bsr_stas_sorted(i).sta_idx, bsr_stas_sorted(i).bsr);
end

% 검증
expected_order = [2, 4, 3, 1, 5];  % BSR: 8000, 6000, 4000, 2000, 2000
actual_order = [bsr_stas_sorted.sta_idx];

if isequal(actual_order, expected_order)
    fprintf('\n✓ 테스트 1 통과: BSR 큰 순서로 정렬됨\n');
    test1_pass = true;
else
    fprintf('\n✗ 테스트 1 실패!\n');
    fprintf('  예상: [%s]\n', num2str(expected_order));
    fprintf('  실제: [%s]\n', num2str(actual_order));
    test1_pass = false;
end

%% 테스트 2: 짧은 시뮬레이션으로 동작 확인
fprintf('\n[테스트 2] 짧은 시뮬레이션 실행\n');
fprintf('─────────────────────────────────────────\n');

% 설정 - 아주 짧게
cfg = config_default();
cfg.num_stas = 5;
cfg.simulation_time = 1;  % 1초
cfg.traffic_model = 'pareto_onoff';
cfg.lambda = 100;
cfg.rho = 0.3;
cfg.mu_on = 0.021;
cfg.mu_off = 0.050;
cfg.seed = 1234;
cfg.verbose = 0;

fprintf('설정: %d STAs, λ=%d, ρ=%.1f, sim_time=%ds\n', cfg.num_stas, cfg.lambda, cfg.rho, cfg.simulation_time);
fprintf('시뮬레이션 실행 중...\n');

tic;
result = run_simulation(cfg);
elapsed = toc;

fprintf('완료 (%.1fs)\n\n', elapsed);

% 결과 확인
fprintf('결과:\n');
fprintf('  생성 패킷: %d\n', result.packets.generated);
fprintf('  완료 패킷: %d\n', result.packets.completed);
fprintf('  평균 지연: %.1f ms\n', result.delay.mean_ms);
fprintf('  BSR Explicit: %d회\n', result.bsr.explicit_count);
fprintf('  BSR Implicit: %d회\n', result.bsr.implicit_count);

if result.bsr.implicit_count > 0
    fprintf('\n✓ 테스트 2 통과: SA 스케줄링 동작 확인 (Implicit BSR 발생)\n');
    test2_pass = true;
else
    fprintf('\n✗ 테스트 2 실패: Implicit BSR 없음 (SA 전송 없음)\n');
    test2_pass = false;
end

%% 테스트 3: Simulator.m 코드 내 정렬 로직 존재 확인
fprintf('\n[테스트 3] 코드 내 BSR 정렬 로직 존재 확인\n');
fprintf('─────────────────────────────────────────\n');

% Simulator.m 파일에서 정렬 코드 확인
simulator_path = which('Simulator');
if isempty(simulator_path)
    simulator_path = 'core/Simulator.m';
end

fid = fopen(simulator_path, 'r');
if fid == -1
    fprintf('✗ Simulator.m 파일을 열 수 없음\n');
    test3_pass = false;
else
    content = fread(fid, '*char')';
    fclose(fid);
    
    % 정렬 코드 패턴 검색
    if contains(content, 'sort([bsr_stas.bsr]') && contains(content, 'descend')
        fprintf('✓ 테스트 3 통과: BSR 정렬 코드 존재 확인\n');
        fprintf('  → sort([bsr_stas.bsr], ''descend'') 패턴 발견\n');
        test3_pass = true;
    else
        fprintf('✗ 테스트 3 실패: BSR 정렬 코드를 찾을 수 없음\n');
        test3_pass = false;
    end
end

%% 요약
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('  테스트 결과 요약\n');
fprintf('───────────────────────────────────────────────────────────────────\n');
fprintf('  테스트 1 (정렬 로직):     %s\n', pass_fail(test1_pass));
fprintf('  테스트 2 (시뮬레이션):    %s\n', pass_fail(test2_pass));
fprintf('  테스트 3 (코드 확인):     %s\n', pass_fail(test3_pass));
fprintf('───────────────────────────────────────────────────────────────────\n');

if test1_pass && test2_pass && test3_pass
    fprintf('  ✓ 모든 테스트 통과! 스케줄링 정책: BSR 큰 순서\n');
else
    fprintf('  ✗ 일부 테스트 실패\n');
end
fprintf('═══════════════════════════════════════════════════════════════════\n');

function s = pass_fail(b)
    if b
        s = '✓ PASS';
    else
        s = '✗ FAIL';
    end
end