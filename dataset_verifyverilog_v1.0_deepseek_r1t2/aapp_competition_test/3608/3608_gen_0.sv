module task_selection #(
    parameter N = 8,
    parameter DATA_WIDTH = 32,
    parameter MOD = 1000000007
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input arrays
    input wire [DATA_WIDTH-1:0] A [0:N-1],
    input wire [DATA_WIDTH-1:0] B [0:N-2],
    
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPUTE = 2'b01;
    localparam [1:0] DONE = 2'b10;
    
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] f, g;
    reg [31:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            f <= {DATA_WIDTH{1'b0}};
            g <= {DATA_WIDTH{1'b0}};
            counter <= 32'd0;
            done <= 1'b0;
            result <= {DATA_WIDTH{1'b0}};
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (N == 32'd1) begin
                            result <= A[0];
                            done <= 1'b1;
                            state <= DONE;
                        end
                        else begin
                            f <= (A[0] + B[0]) % MOD;
                            g <= B[0] % MOD;
                            counter <= 32'd1;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Update g
                    if (counter < (N-1)) 
                        g <= (f * B[counter]) % MOD;
                    else
                        g <= {DATA_WIDTH{1'b0}};
                    
                    // Update f
                    f <= (f * (A[counter] + B[counter-1]) + 
                          (counter < (N-1) ? (f * B[counter]) : {DATA_WIDTH{1'b0}}) - 
                          g + MOD) % MOD;
                    
                    // State transition
                    if (counter == (N-1)) begin
                        result <= f;
                        done <= 1'b1;
                        state <= DONE;
                    end
                    else begin
                        counter <= counter + 32'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule