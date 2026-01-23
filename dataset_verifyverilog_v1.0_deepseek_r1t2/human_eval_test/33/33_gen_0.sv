module sort_third (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] EXTRACT  = 3'd2;
    localparam [2:0] SORT     = 3'd3;
    localparam [2:0] RESTORE  = 3'd4;
    localparam [2:0] DONE_ST  = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [7:0] original_arr [0:7];
    reg [7:0] sort_regs [0:2];
    reg [1:0] pass_count;
    reg [1:0] comp_count;
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                original_arr[i] <= 8'd0;
                result[i] <= 8'd0;
            end
            for (j = 0; j < 3; j = j + 1) begin
                sort_regs[j] <= 8'd0;
            end
            pass_count <= 2'd0;
            comp_count <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Capture input array
                    for (i = 0; i < 8; i = i + 1) begin
                        original_arr[i] <= arr[i];
                    end
                    state <= EXTRACT;
                end

                EXTRACT: begin
                    sort_regs[0] <= original_arr[0];
                    sort_regs[1] <= original_arr[3];
                    sort_regs[2] <= original_arr[6];
                    pass_count <= 2'd0;
                    comp_count <= 2'd0;
                    state <= SORT;
                end

                SORT: begin
                    if (pass_count < 2'd2) begin
                        if (comp_count == 2'd0) begin
                            // Compare & swap 0 & 1
                            if (sort_regs[0] > sort_regs[1]) begin
                                sort_regs[0] <= sort_regs[1];
                                sort_regs[1] <= sort_regs[0];
                            end
                            comp_count <= comp_count + 2'd1;
                        end else begin
                            // Compare & swap 1 & 2
                            if (sort_regs[1] > sort_regs[2]) begin
                                sort_regs[1] <= sort_regs[2];
                                sort_regs[2] <= sort_regs[1];
                            end
                            comp_count <= 2'd0;
                            pass_count <= pass_count + 2'd1;
                        end
                    end else begin
                        state <= RESTORE;
                    end
                end

                RESTORE: begin
                    // Place sorted elements back
                    result[0] <= sort_regs[0];
                    result[3] <= sort_regs[1];
                    result[6] <= sort_regs[2];
                    // Preserve other indices
                    result[1] <= original_arr[1];
                    result[2] <= original_arr[2];
                    result[4] <= original_arr[4];
                    result[5] <= original_arr[5];
                    result[7] <= original_arr[7];
                    state <= DONE_ST;
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule