module ArrayIncrement(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_in [0:7],
    input [3:0] len,
    output reg [7:0] arr_out [0:7],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] LATCH   = 4'd1;
    localparam [3:0] PROCESS = 4'd2;
    localparam [3:0] DONE_STATE = 4'd3;
    
    reg [3:0] state;
    reg [3:0] cycle_count;
    reg [7:0] latched_arr [0:7];
    reg [3:0] latched_len;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr_out[i] <= 8'd0;
                latched_arr[i] <= 8'd0;
            end
            latched_len <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= LATCH;
                    end
                end
                
                LATCH: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        latched_arr[i] <= arr_in[i];
                    end
                    latched_len <= len;
                    state <= PROCESS;
                    cycle_count <= 4'd0;
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Process all elements in one cycle (combinatorial)
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < latched_len) begin
                            if (latched_arr[i] == 8'd255) begin
                                arr_out[i] <= 8'd0;
                            end else begin
                                arr_out[i] <= latched_arr[i] + 8'd1;
                            end
                        end else begin
                            arr_out[i] <= 8'd0;
                        end
                    end
                    
                    if (cycle_count >= 4'd1) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule