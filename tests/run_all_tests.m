function run_all_tests()
% RUN_ALL_TESTS: 모든 단위 테스트 실행
%
% 사용법:
%   run_all_tests()

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║              WiFi 6 T_hold Simulator - 단위 테스트            ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    % 경로 설정
    test_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(test_dir);
    addpath(genpath(project_root));
    
    % 테스트 결과 저장
    results = struct('name', {}, 'passed', {}, 'failed', {}, 'errors', {});
    
    % 테스트 목록
    tests = {
        'test_config'
        'test_sta'
        'test_uora'
        'test_traffic'
        'test_integration'
    };
    
    total_passed = 0;
    total_failed = 0;
    
    for i = 1:length(tests)
        test_name = tests{i};
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        fprintf('실행: %s\n', test_name);
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        try
            [passed, failed] = feval(test_name);
            total_passed = total_passed + passed;
            total_failed = total_failed + failed;
            
            results(end+1).name = test_name;
            results(end).passed = passed;
            results(end).failed = failed;
            results(end).errors = {};
        catch ME
            fprintf('  ❌ 테스트 실행 오류: %s\n', ME.message);
            total_failed = total_failed + 1;
            
            results(end+1).name = test_name;
            results(end).passed = 0;
            results(end).failed = 1;
            results(end).errors = {ME.message};
        end
        fprintf('\n');
    end
    
    % 결과 요약
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                        테스트 결과 요약                       ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    for i = 1:length(results)
        if results(i).failed == 0
            status = '✅ PASS';
        else
            status = '❌ FAIL';
        end
        fprintf('  %s: %s (%d passed, %d failed)\n', ...
            results(i).name, status, results(i).passed, results(i).failed);
    end
    
    fprintf('\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    if total_failed == 0
        fprintf('  ✅ 모든 테스트 통과! (%d/%d)\n', total_passed, total_passed + total_failed);
    else
        fprintf('  ❌ 일부 테스트 실패 (%d passed, %d failed)\n', total_passed, total_failed);
    end
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
end