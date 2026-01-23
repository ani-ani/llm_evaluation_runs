module count_representations (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] bin_bits,
    input wire [3:0] length,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] index;
    reg [31:0] dp0, dp1;
    reg [31:0] temp_sum;
    
    // Modular addition helper
    always @(*) begin
        temp_sum = dp0 + dp1;
        if (temp_sum >= 1000000009) begin
            temp_sum = temp_sum - 1000000009;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            dp0 <= 32'd0;
            dp1 <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        dp0 <= 32'd1;
                        dp1 <= 32'd0;
                    end
                end
                
                PROCESS: begin
                    if (bin_bits[index] == 1'b0) begin
                        dp0 <= dp0;
                        dp1 <= temp_sum;
                    end else begin
                        dp0 <= temp_sum;
                        dp1 <= dp1;
                    end
                    
                    if (index == length - 1) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end
                end
                
                FINISH: begin
                    if (bin_bits[index] == 1'b0) begin
                        result <= dp0;
                    end else begin
                        result <= temp_sum;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule