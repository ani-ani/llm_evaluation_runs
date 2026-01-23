module square_perimeter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] side_length,
    output reg [15:0] perimeter,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perimeter <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Perimeter = 4 * side_length
                    // side_length << 2 (multiply by 4)
                    perimeter <= {2'b00, side_length, 2'b00};
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    perimeter <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule