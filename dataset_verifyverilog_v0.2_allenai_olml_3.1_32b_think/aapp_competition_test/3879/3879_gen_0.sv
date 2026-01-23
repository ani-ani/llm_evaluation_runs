module jackpot_checker (input clk, input rst_n, input start, input [2:0] num_inputs, input [15:0] data_in, input data_valid, output reg result, output reg done);

function automatic [15:0] compute_core;
    input [15:0] num;
    reg [15:0] temp;
    temp = num;
    // Remove factors of 2
    for (int i=0; i<16; i++) begin
        if (temp % 2 == 1) break;
        temp = temp >> 1;
    end
    // Remove factors of 3
    for (int i=0; i<20; i++) begin
        if (temp % 3 != 0) break;
        temp = temp / 3;
    end
    compute_core = temp;
endfunction

// Registers
reg [1:0] state;
reg [2:0] num_to_collect;
reg [2:0] collect_count;
reg [15:0] stored_values [7:0];
reg [2:0] process_index;
reg [15:0] reference_core;
reg mismatch;
reg result;
reg done;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        num_to_collect <= 3'b000;
        collect_count <= 3'b000;
        for (int i=0; i<8; i++) stored_values[i] <= 16'b0;
        process_index <= 3'b000;
        reference_core <= 16'b0;
        mismatch <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            2'b00: // IDLE
                if (start) begin
                    state <= 2'b01;
                    num_to_collect <= num_inputs;
                    collect_count <= 3'b000;
                end
            end
            2'b01: // COLLECT
                if (data_valid) begin
                    stored_values[collect_count] <= data_in;
                    collect_count <= collect_count + 1;
                    if (collect_count == num_to_collect) begin
                        state <= 2'b10;
                        process_index <= 3'b000;
                        mismatch <= 1'b0;
                    end
                end
            end
            2'b10: // PROCESS
                if (process_index < num_to_collect) begin
                    if (process_index == 0) begin
                        reference_core <= compute_core(stored_values[process_index]);
                    end else begin
                        if (compute_core(stored_values[process_index]) != reference_core) begin
                            mismatch <= 1'b1;
                        end
                    end
                    process_index <= process_index + 1;
                end else begin
                    if (!mismatch) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= 2'b11;
                    done <= 1'b1;
                end
            end
            2'b11: // DONE
                // No action, retain values
            endcase
        end
    end
endmodule