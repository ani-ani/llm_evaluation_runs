module StringArrayAppend(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] list_str_id_0,
    input wire [7:0] list_str_id_1,
    input wire [7:0] input_str_id,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [3:0] result_len,
    output reg done
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LATCH   = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH  = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    reg [7:0] latched_list_str_id_0;
    reg [7:0] latched_list_str_id_1;
    reg [7:0] latched_input_str_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            latched_list_str_id_0 <= 8'd0;
            latched_list_str_id_1 <= 8'd0;
            latched_input_str_id <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LATCH;
                    end
                end
                
                LATCH: begin
                    latched_list_str_id_0 <= list_str_id_0;
                    latched_list_str_id_1 <= list_str_id_1;
                    latched_input_str_id <= input_str_id;
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count == 8'd4) begin
                        result_0 <= latched_list_str_id_0;
                        result_1 <= latched_list_str_id_1;
                        result_2 <= latched_input_str_id;
                        result_len <= 4'd3;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule