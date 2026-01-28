module sort_third(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] EXTRACT = 3'd2;
    localparam [2:0] SORT    = 3'd3;
    localparam [2:0] RESTORE = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    reg [2:0] state;
    reg [7:0] temp_arr [0:7];
    reg [7:0] extracted [0:2];
    reg [7:0] sorted [0:2];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                temp_arr[i] <= 8'd0;
            end
            for (integer i = 0; i < 3; i = i + 1) begin
                extracted[i] <= 8'd0;
                sorted[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    for (integer i = 0; i < 8; i = i + 1) begin
                        temp_arr[i] <= arr[i];
                    end
                    state <= EXTRACT;
                end

                EXTRACT: begin
                    extracted[0] <= temp_arr[0];
                    extracted[1] <= temp_arr[3];
                    extracted[2] <= temp_arr[6];
                    state <= SORT;
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Bubble sort for 3 elements
                    if (cycle_count < 8'd3) begin
                        if (cycle_count == 8'd0) begin
                            sorted[0] <= extracted[0];
                            sorted[1] <= extracted[1];
                            sorted[2] <= extracted[2];
                        end else if (cycle_count == 8'd1) begin
                            if (sorted[0] > sorted[1]) begin
                                sorted[0] <= extracted[1];
                                sorted[1] <= extracted[0];
                            end
                            if (sorted[1] > sorted[2]) begin
                                sorted[1] <= extracted[2];
                                sorted[2] <= extracted[1];
                            end
                        end else if (cycle_count == 8'd2) begin
                            if (sorted[0] > sorted[1]) begin
                                sorted[0] <= sorted[1];
                                sorted[1] <= sorted[0];
                            end
                        end
                    end else begin
                        state <= RESTORE;
                    end
                end

                RESTORE: begin
                    result[0] <= sorted[0];
                    result[1] <= temp_arr[1];
                    result[2] <= temp_arr[2];
                    result[3] <= sorted[1];
                    result[4] <= temp_arr[4];
                    result[5] <= temp_arr[5];
                    result[6] <= sorted[2];
                    result[7] <= temp_arr[7];
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule