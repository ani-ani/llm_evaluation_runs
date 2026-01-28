module TemperaturePredictor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [11:0] temp_data,
    input wire temp_valid,
    input wire [6:0] n_in,
    output reg signed [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] READ_FIRST   = 3'd1;
    localparam [2:0] READ_SECOND  = 3'd2;
    localparam [2:0] VERIFY_LOOP  = 3'd3;
    localparam [2:0] CALCULATE    = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg signed [11:0] t0, t1, prev_temp;
    reg signed [12:0] diff;
    reg [6:0] counter;
    reg [6:0] n_reg;
    reg is_arithmetic;
    reg signed [15:0] result_reg;
    
    // Control signals
    reg load_start, load_t0, load_t1, load_temp, clear_flag;
    reg inc_counter, reset_counter;
    reg calc_result, assert_done;

    // State transition logic
    always @(*) begin
        next_state = state;
        load_start = 1'b0;
        load_t0 = 1'b0;
        load_t1 = 1'b0;
        load_temp = 1'b0;
        clear_flag = 1'b0;
        inc_counter = 1'b0;
        reset_counter = 1'b0;
        calc_result = 1'b0;
        assert_done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start && temp_valid) begin
                    load_start = 1'b1;
                    next_state = READ_FIRST;
                end
            end
            
            READ_FIRST: begin
                if (temp_valid) begin
                    load_t0 = 1'b1;
                    if (n_reg == 7'd2) begin
                        // Only 2 temperatures, need second one
                        next_state = READ_SECOND;
                    end else begin
                        next_state = READ_SECOND;
                    end
                end
            end
            
            READ_SECOND: begin
                if (temp_valid) begin
                    load_t1 = 1'b1;
                    if (n_reg == 7'd2) begin
                        // Only 2 temps, calculate immediately
                        next_state = CALCULATE;
                    end else begin
                        reset_counter = 1'b1;
                        clear_flag = 1'b1;
                        next_state = VERIFY_LOOP;
                    end
                end
            end
            
            VERIFY_LOOP: begin
                if (temp_valid) begin
                    load_temp = 1'b1;
                    if (counter >= n_reg - 7'd2) begin
                        // Last temp processed
                        next_state = CALCULATE;
                    end else begin
                        inc_counter = 1'b1;
                    end
                end
            end
            
            CALCULATE: begin
                calc_result = 1'b1;
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                assert_done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            t0 <= 12'sd0;
            t1 <= 12'sd0;
            prev_temp <= 12'sd0;
            diff <= 13'sd0;
            counter <= 7'd0;
            n_reg <= 7'd0;
            is_arithmetic <= 1'b0;
            result_reg <= 16'sd0;
            result <= 16'sd0;
            done <= 1'b0;
            ready <= 1'b1;
        end else begin
            // Default values
            done <= 1'b0;
            
            // State machine
            state <= next_state;
            
            if (load_start) begin
                n_reg <= n_in;
                ready <= 1'b0;
            end
            
            if (load_t0) begin
                t0 <= temp_data;
                prev_temp <= temp_data;
            end
            
            if (load_t1) begin
                t1 <= temp_data;
                diff <= temp_data - t0;
                prev_temp <= temp_data;
                counter <= 7'd0;
            end
            
            if (clear_flag) begin
                is_arithmetic <= 1'b1;
            end
            
            if (load_temp) begin
                // Check if current - previous == diff
                if ((temp_data - prev_temp) !== diff) begin
                    is_arithmetic <= 1'b0;
                end
                prev_temp <= temp_data;
            end
            
            if (inc_counter) begin
                counter <= counter + 7'd1;
            end
            
            if (calc_result) begin
                if (is_arithmetic) begin
                    // result = last_temp + diff
                    result_reg <= prev_temp + diff;
                end else begin
                    // result = last_temp
                    result_reg <= prev_temp;
                end
            end
            
            if (assert_done) begin
                result <= result_reg;
                done <= 1'b1;
                ready <= 1'b1;
            end
            
            // Reset counter when starting new operation
            if (reset_counter) begin
                counter <= 7'd0;
            end
        end
    end

endmodule