module lucky_permutation_triple(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg done,
    output reg valid,
    output reg [7:0] a [0:7],
    output reg [7:0] b [0:7],
    output reg [7:0] c [0:7]
);

    // State declarations
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] COMPUTE = 1'b1;
    
    reg [0:0] state;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            // Initialize all array elements
            for (i = 0; i < 8; i = i + 1) begin
                a[i] <= 8'd0;
                b[i] <= 8'd0;
                c[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Check if n is valid (odd and <= 8)
                        valid <= (n[0] == 1'b1) && (n <= 8);
                        
                        // Compute permutations
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < n && n[0] == 1'b1) begin
                                a[i] <= i;
                                b[i] <= i;
                                // Compute c[i] = (2*i) % n
                                if (2*i >= n)
                                    c[i] <= 2*i - n;
                                else
                                    c[i] <= 2*i;
                            end else begin
                                a[i] <= 8'd0;
                                b[i] <= 8'd0;
                                c[i] <= 8'd0;
                            end
                        end
                        
                        state <= COMPUTE;
                        done <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule