module gcd_table_solver #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter MAX_ENTRIES = 16,
    parameter CLK_PERIOD = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire data_valid,
    output reg [DATA_WIDTH-1:0] result,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_INPUT = 4'd1;
    localparam [3:0] S_SORT = 4'd2;
    localparam [3:0] S_BUILD_DISTINCT = 4'd3;
    localparam [3:0] S_FIND_CANDIDATE = 4'd4;
    localparam [3:0] S_DECREMENT_CANDIDATE = 4'd5;
    localparam [3:0] S_PROCESS_RESULTS = 4'd6;
    localparam [3:0] S_COMPUTE_GCD = 4'd7;
    localparam [3:0] S_FIND_GCD = 4'd8;
    localparam [3:0] S_DECREMENT_GCD = 4'd9;
    localparam [3:0] S_APPEND_RESULT = 4'd10;
    localparam [3:0] S_OUTPUT = 4'd11;
    localparam [3:0] S_DONE = 4'd12;

    // Internal registers
    reg [3:0] state, next_state;
    reg [DATA_WIDTH-1:0] buffer [0:MAX_ENTRIES-1];
    reg [DATA_WIDTH-1:0] distinct [0:MAX_ENTRIES-1];
    reg [DATA_WIDTH-1:0] result_array [0:N-1];
    reg [DATA_WIDTH-1:0] candidate;
    reg [DATA_WIDTH-1:0] current_gcd;
    reg [DATA_WIDTH-1:0] temp_a, temp_b;
    reg [3:0] input_count;
    reg [3:0] distinct_count;
    reg [3:0] result_count;
    reg [3:0] sort_i, sort_j;
    reg [3:0] build_i, build_j;
    reg [3:0] candidate_i;
    reg [3:0] gcd_i, gcd_j;
    reg [3:0] process_i;
    reg [3:0] output_i;
    reg [3:0] gcd_cycle;
    reg [3:0] cycle_count;
    reg found_candidate;
    reg found_gcd;
    reg [DATA_WIDTH-1:0] count [0:MAX_ENTRIES-1];
    reg [DATA_WIDTH-1:0] temp_count;

    // GCD computation registers
    reg [DATA_WIDTH-1:0] gcd_a, gcd_b, gcd_result;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= {DATA_WIDTH{1'b0}};
            result_valid <= 1'b0;
            done <= 1'b0;
            input_count <= 4'd0;
            distinct_count <= 4'd0;
            result_count <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            build_i <= 4'd0;
            build_j <= 4'd0;
            candidate_i <= 4'd0;
            gcd_i <= 4'd0;
            gcd_j <= 4'd0;
            process_i <= 4'd0;
            output_i <= 4'd0;
            gcd_cycle <= 4'd0;
            cycle_count <= 4'd0;
            found_candidate <= 1'b0;
            found_gcd <= 1'b0;
            candidate <= {DATA_WIDTH{1'b0}};
            current_gcd <= {DATA_WIDTH{1'b0}};
            temp_a <= {DATA_WIDTH{1'b0}};
            temp_b <= {DATA_WIDTH{1'b0}};
            gcd_a <= {DATA_WIDTH{1'b0}};
            gcd_b <= {DATA_WIDTH{1'b0}};
            gcd_result <= {DATA_WIDTH{1'b0}};
            temp_count <= {DATA_WIDTH{1'b0}};

            integer i;
            for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
                buffer[i] <= {DATA_WIDTH{1'b0}};
                distinct[i] <= {DATA_WIDTH{1'b0}};
                count[i] <= {DATA_WIDTH{1'b0}};
            end
            for (i = 0; i < N; i = i + 1) begin
                result_array[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_INPUT;
                end
            end
            S_INPUT: begin
                if (input_count == MAX_ENTRIES - 1 && data_valid) begin
                    next_state = S_SORT;
                end
            end
            S_SORT: begin
                if (sort_i == MAX_ENTRIES - 1 && sort_j == MAX_ENTRIES - sort_i - 1) begin
                    next_state = S_BUILD_DISTINCT;
                end
            end
            S_BUILD_DISTINCT: begin
                if (build_i == MAX_ENTRIES) begin
                    next_state = S_FIND_CANDIDATE;
                end
            end
            S_FIND_CANDIDATE: begin
                if (found_candidate) begin
                    next_state = S_DECREMENT_CANDIDATE;
                end else if (candidate_i == distinct_count) begin
                    next_state = S_OUTPUT;
                end
            end
            S_DECREMENT_CANDIDATE: begin
                next_state = S_PROCESS_RESULTS;
            end
            S_PROCESS_RESULTS: begin
                if (process_i == result_count) begin
                    next_state = S_COMPUTE_GCD;
                end
            end
            S_COMPUTE_GCD: begin
                if (gcd_cycle == 8) begin
                    next_state = S_FIND_GCD;
                end
            end
            S_FIND_GCD: begin
                if (found_gcd) begin
                    next_state = S_DECREMENT_GCD;
                end else if (gcd_i == distinct_count) begin
                    next_state = S_APPEND_RESULT;
                end
            end
            S_DECREMENT_GCD: begin
                next_state = S_FIND_GCD;
            end
            S_APPEND_RESULT: begin
                next_state = S_FIND_CANDIDATE;
            end
            S_OUTPUT: begin
                if (output_i == result_count) begin
                    next_state = S_DONE;
                end
            end
            S_DONE: begin
                if (start) begin
                    next_state = S_INPUT;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Input collection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_count <= 4'd0;
        end else if (state == S_INPUT && data_valid) begin
            buffer[input_count] <= data_in;
            input_count <= input_count + 4'd1;
        end
    end

    // Bubble sort
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i <= 4'd0;
            sort_j <= 4'd0;
        end else if (state == S_SORT) begin
            if (buffer[sort_j] < buffer[sort_j + 1]) begin
                temp_a <= buffer[sort_j];
                temp_b <= buffer[sort_j + 1];
                buffer[sort_j] <= temp_b;
                buffer[sort_j + 1] <= temp_a;
            end
            if (sort_j == MAX_ENTRIES - sort_i - 2) begin
                sort_j <= 4'd0;
                sort_i <= sort_i + 4'd1;
            end else begin
                sort_j <= sort_j + 4'd1;
            end
        end
    end

    // Build distinct array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            build_i <= 4'd0;
            build_j <= 4'd0;
            distinct_count <= 4'd0;
        end else if (state == S_BUILD_DISTINCT) begin
            if (build_i == 0 || buffer[build_i] != distinct[distinct_count]) begin
                distinct[distinct_count] <= buffer[build_i];
                count[distinct_count] <= 4'd1;
                distinct_count <= distinct_count + 4'd1;
            end else begin
                count[distinct_count - 1] <= count[distinct_count - 1] + 4'd1;
            end
            build_i <= build_i + 4'd1;
        end
    end

    // Find candidate
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            candidate_i <= 4'd0;
            found_candidate <= 1'b0;
            candidate <= {DATA_WIDTH{1'b0}};
        end else if (state == S_FIND_CANDIDATE) begin
            if (count[candidate_i] > 0) begin
                candidate <= distinct[candidate_i];
                found_candidate <= 1'b1;
            end else begin
                candidate_i <= candidate_i + 4'd1;
            end
        end
    end

    // Decrement candidate count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset
        end else if (state == S_DECREMENT_CANDIDATE) begin
            count[candidate_i] <= count[candidate_i] - 4'd1;
        end
    end

    // Process results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            process_i <= 4'd0;
        end else if (state == S_PROCESS_RESULTS) begin
            if (process_i < result_count) begin
                gcd_a <= candidate;
                gcd_b <= result_array[process_i];
                process_i <= process_i + 4'd1;
            end
        end
    end

    // Compute GCD
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_cycle <= 4'd0;
            gcd_a <= {DATA_WIDTH{1'b0}};
            gcd_b <= {DATA_WIDTH{1'b0}};
            gcd_result <= {DATA_WIDTH{1'b0}};
        end else if (state == S_COMPUTE_GCD) begin
            if (gcd_cycle == 0) begin
                gcd_result <= gcd_a;
            end else if (gcd_b != 0) begin
                gcd_result <= gcd_b;
                gcd_b <= gcd_a % gcd_b;
                gcd_a <= gcd_result;
            end
            gcd_cycle <= gcd_cycle + 4'd1;
        end
    end

    // Find GCD in distinct array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_i <= 4'd0;
            found_gcd <= 1'b0;
            current_gcd <= {DATA_WIDTH{1'b0}};
        end else if (state == S_FIND_GCD) begin
            if (distinct[gcd_i] == gcd_result) begin
                current_gcd <= distinct[gcd_i];
                found_gcd <= 1'b1;
            end else begin
                gcd_i <= gcd_i + 4'd1;
            end
        end
    end

    // Decrement GCD count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset
        end else if (state == S_DECREMENT_GCD) begin
            for (gcd_j = 0; gcd_j < distinct_count; gcd_j = gcd_j + 1) begin
                if (distinct[gcd_j] == current_gcd) begin
                    count[gcd_j] <= count[gcd_j] - 4'd2;
                end
            end
        end
    end

    // Append result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 4'd0;
        end else if (state == S_APPEND_RESULT) begin
            result_array[result_count] <= candidate;
            result_count <= result_count + 4'd1;
            candidate_i <= 4'd0;
            found_candidate <= 1'b0;
        end
    end

    // Output results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_i <= 4'd0;
            result_valid <= 1'b0;
        end else if (state == S_OUTPUT) begin
            result <= result_array[output_i];
            result_valid <= 1'b1;
            output_i <= output_i + 4'd1;
        end else begin
            result_valid <= 1'b0;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == S_DONE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule