module jackpot_checker(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_inputs,
    input [15:0] data_in,
    input data_valid,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam COLLECT = 2'b01;
    localparam PROCESS = 2'b10;
    localparam DONE = 2'b11;

    // Internal Registers
    reg [1:0] current_state, next_state;
    reg [15:0] stored_values [0:7];
    reg [2:0] input_cnt;
    reg [2:0] proc_idx;
    reg [15:0] core_ref;
    reg mismatch_flag;
    reg [7:0] cycle_cnt;
    reg processing_active;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: next_state = start ? COLLECT : IDLE;
            COLLECT: next_state = (input_cnt == num_inputs && num_inputs != 0) ? PROCESS : COLLECT;
            // Wait in PROCESS until latency met (200 cycles)
            PROCESS: next_state = (cycle_cnt >= 8'd200) ? DONE : PROCESS;
            DONE: next_state = start ? COLLECT : DONE; // Restart on start
            default: next_state = IDLE;
        endcase
    end

    // Function to calculate core
    function [15:0] calc_core;
        input [15:0] val;
        reg [15:0] temp;
        begin
            temp = val;
            // Divide by 2
            while (temp[0] == 0 && temp != 0) temp = temp >> 1;
            // Divide by 3
            while (temp != 0 && temp % 3 == 0) temp = temp / 3;
            calc_core = temp;
        end
    endfunction

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_cnt <= 3'b0;
            proc_idx <= 3'b0;
            mismatch_flag <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_cnt <= 8'd0;
            processing_active <= 1'b0;
        end else begin
            done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    input_cnt <= 3'b0;
                    proc_idx <= 3'b0;
                    mismatch_flag <= 1'b0;
                    cycle_cnt <= 8'd0;
                    processing_active <= 1'b0;
                end

                COLLECT: begin
                    if (data_valid && input_cnt < num_inputs) begin
                        stored_values[input_cnt] <= data_in;
                        input_cnt <= input_cnt + 1'b1;
                    end
                end

                PROCESS: begin
                    // Increment cycle counter
                    cycle_cnt <= cycle_cnt + 1'b1;

                    // Logic to process one number per cycle (sequential for each number)
                    // We need to process indices 0 to (input_cnt - 1)
                    // We only start if we haven't finished processing all inputs
                    
                    // Check if we have a valid index to process
                    if (proc_idx < input_cnt) begin
                        // Calculate core of current index using the function
                        // The function is combinational, so the result is available immediately
                        // Note: Inputs to function must be stable. 
                        // Here, `stored_values[proc_idx]` is stable because `proc_idx` is stable for the cycle.
                        
                        // Perform action based on index
                        if (proc_idx == 3'b000) begin
                            // First number: Save as reference
                            core_ref <= calc_core(stored_values[proc_idx]);
                        end else begin
                            // Subsequent numbers: Compare with reference
                            if (calc_core(stored_values[proc_idx]) != core_ref)
                                mismatch_flag <= 1'b1;
                        end
                        
                        // Increment index to process next number in the next cycle
                        proc_idx <= proc_idx + 1'b1;
                    end
                    // If proc_idx >= input_cnt, we stop processing new numbers, but keep waiting for latency
                end

                DONE: begin
                    done <= 1'b1;
                    // Latch result
                    // If there was no mismatch AND at least one number was processed
                    if (input_cnt > 0 && !mismatch_flag)
                        result <= 1'b1;
                    else
                        result <= 1'b0;
                end
            endcase
        end
    end

endmodule