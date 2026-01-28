module alt_subseq(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [63:0] data,
    output reg [6:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd50;
    
    reg [5:0] i;
    reg [6:0] C;
    reg has_collision;
    reg [6:0] base_length;
    reg [6:0] final_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 7'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
            i <= 6'd0;
            C <= 7'd0;
            has_collision <= 1'b0;
            base_length <= 7'd0;
            final_result <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 6'd0;
                        C <= 7'd0;
                        has_collision <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    if (cycle_count < MAX_CYCLES) begin
                        if (i < n - 1) begin
                            if (data[i] != data[i + 1]) begin
                                C <= C + 7'd1;
                            end else begin
                                has_collision <= 1'b1;
                            end
                            i <= i + 6'd1;
                        end else begin
                            base_length <= C + 7'd1;
                            if (has_collision) begin
                                final_result <= base_length + 7'd2;
                            end else if (n > 1) begin
                                final_result <= base_length + 7'd1;
                            end else begin
                                final_result <= base_length;
                            end
                            
                            if (final_result > n) begin
                                final_result <= n;
                            end
                            
                            result <= final_result;
                            state <= FINISH;
                        end
                    end else begin
                        result <= 7'd0;
                        state <= IDLE;
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