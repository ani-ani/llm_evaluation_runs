module multicombination(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg done,
    output reg out_valid,
    output reg [9:0] [7:0] out_array,
    output reg [3:0] out_count
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for computation
    reg [3:0] current_n;
    reg [1:0] color0, color1, color2;
    reg [3:0] count;
    reg [3:0] i, j, k;
    reg [3:0] index;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            out_count <= 4'd0;
            cycle_count <= 8'd0;
            current_n <= 4'd0;
            color0 <= 2'd0;
            color1 <= 2'd0;
            color2 <= 2'd0;
            count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            index <= 4'd0;
            
            // Initialize output array
            integer idx;
            for (idx = 0; idx < 10; idx = idx + 1) begin
                out_array[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        current_n <= n;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    case (current_n)
                        4'd1: begin  // n=1
                            if (i < 3) begin
                                out_array[i] <= {6'd0, i[1:0]};
                                i <= i + 4'd1;
                            end else begin
                                out_count <= 4'd3;
                                state <= FINISH;
                            end
                        end
                        
                        4'd2: begin  // n=2
                            if (j < 3) begin
                                if (k < 3) begin
                                    if (k[1:0] >= j[1:0]) begin
                                        out_array[index] <= {4'd0, k[1:0], j[1:0]};
                                        index <= index + 4'd1;
                                    end
                                    k <= k + 4'd1;
                                end else begin
                                    k <= 4'd0;
                                    j <= j + 4'd1;
                                end
                            end else begin
                                out_count <= 4'd6;
                                state <= FINISH;
                            end
                        end
                        
                        4'd3: begin  // n=3
                            if (color0 < 3) begin
                                if (color1 < 3) begin
                                    if (color2 < 3) begin
                                        if (color1[1:0] >= color0[1:0] && color2[1:0] >= color1[1:0]) begin
                                            out_array[index] <= {color2[1:0], color1[1:0], color0[1:0], 2'd0};
                                            index <= index + 4'd1;
                                        end
                                        color2 <= color2 + 2'd1;
                                    end else begin
                                        color2 <= 2'd0;
                                        color1 <= color1 + 2'd1;
                                    end
                                end else begin
                                    color1 <= 2'd0;
                                    color0 <= color0 + 2'd1;
                                end
                            end else begin
                                out_count <= 4'd10;
                                state <= FINISH;
                            end
                        end
                        
                        default: begin
                            out_count <= 4'd0;
                            state <= FINISH;
                        end
                    endcase
                    
                    // Safety exit condition
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    out_valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule