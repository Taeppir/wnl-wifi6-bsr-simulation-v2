%% run_all_additional_exp.m
% 추가 실험 1, 2를 순차적으로 실행하는 마스터 스크립트
%
% 밤새 돌리기용

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║              추가 실험 전체 실행 (밤새 돌리기용)                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

total_start = tic;

%% 추가 실험 1 실행
fprintf('========================================\n');
fprintf('  추가 실험 1 시작\n');
fprintf('========================================\n');
try
    run('run_additional_exp1.m');
    fprintf('\n[추가 실험 1 완료]\n\n');
catch ME
    fprintf('\n[추가 실험 1 오류]: %s\n\n', ME.message);
end

%% 추가 실험 2 실행
fprintf('========================================\n');
fprintf('  추가 실험 2 시작\n');
fprintf('========================================\n');
try
    run('run_additional_exp2.m');
    fprintf('\n[추가 실험 2 완료]\n\n');
catch ME
    fprintf('\n[추가 실험 2 오류]: %s\n\n', ME.message);
end

%% 완료
total_elapsed = toc(total_start);
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                        전체 실험 완료                             ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
fprintf('║  총 실행 시간: %6.1f분 (%.1f시간)                               ║\n', ...
    total_elapsed/60, total_elapsed/3600);
fprintf('║                                                                  ║\n');
fprintf('║  결과 파일:                                                      ║\n');
fprintf('║    - results/additional_exp1/results.mat                        ║\n');
fprintf('║    - results/additional_exp2/results.mat                        ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n');