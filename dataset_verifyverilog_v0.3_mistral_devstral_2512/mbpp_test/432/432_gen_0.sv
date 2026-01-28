module trapezium_median (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [15:0] base1,
    input  wire [15:0] base2,
    input  wire [15:0] height,
    output reg  [15:0] median,
    output reg         done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [16:0] sum;  // 17-bit to hold sum of two 16-bit values
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            median <= 16'd0;
            done <= 1'b0;
            sum <= 17'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    sum <= {1'b0, base1} + {1'b0, base2};
                    median <= sum[16:1];  // Divide by 2 (shift right)
                    state <= FINISH;
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