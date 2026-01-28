module list_replace(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] in1 [0:7],
    input wire [7:0] in2 [0:7],
    input wire [3:0] len1,
    input wire [3:0] len2,
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd50;

    integer i;
    reg [7:0] temp_result [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 6'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                temp_result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Initialize temp_result with zeros
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_result[i] <= 8'd0;
                    end
                    
                    // Copy elements from in1 (except last)
                    for (i = 0; i < len1 - 4'd1; i = i + 1) begin
                        if (i < 8) begin
                            temp_result[i] <= in1[i];
                        end
                    end
                    
                    // Copy elements from in2
                    for (i = 0; i < len2; i = i + 1) begin
                        if ((len1 - 4'd1 + i) < 8) begin
                            temp_result[len1 - 4'd1 + i] <= in2[i];
                        end
                    end
                    
                    // Copy temp_result to result
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= temp_result[i];
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES - 6'd1) begin
                        state <= FINISH;
                    end else begin
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