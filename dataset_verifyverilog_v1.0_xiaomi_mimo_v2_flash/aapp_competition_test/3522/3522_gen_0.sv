module battery_allocator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [7:0] batteries [0:15],
    output reg [7:0] result,
    output reg done
);
    parameter MAX_BATTERIES = 16;
    
    // State definitions
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] COPY    = 4'd1;
    localparam [3:0] SORT    = 4'd2;
    localparam [3:0] COMPUTE = 4'd3;
    localparam [3:0] RESULT  = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;
    
    // Registers
    reg [3:0] state;
    reg [7:0] mem [0:15];
    reg [3:0] copy_cnt;
    reg [3:0] outer_cnt;
    reg [3:0] inner_cnt;
    reg [3:0] compute_cnt;
    reg [7:0] max_diff;
    
    // Combinational logic
    wire [7:0] diff;
    assign diff = mem[2*compute_cnt + 1] - mem[2*compute_cnt];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            copy_cnt <= 4'd0;
            outer_cnt <= 4'd0;
            inner_cnt <= 4'd0;
            compute_cnt <= 4'd0;
            max_diff <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        copy_cnt <= 4'd0;
                        state <= COPY;
                    end
                end
                
                COPY: begin
                    mem[copy_cnt] <= batteries[copy_cnt];
                    if (copy_cnt == MAX_BATTERIES - 1) begin
                        outer_cnt <= 4'd0;
                        inner_cnt <= 4'd0;
                        state <= SORT;
                    end else begin
                        copy_cnt <= copy_cnt + 4'd1;
                    end
                end
                
                SORT: begin
                    if (inner_cnt < MAX_BATTERIES - 1 - outer_cnt) begin
                        if (mem[inner_cnt] > mem[inner_cnt + 1]) begin
                            mem[inner_cnt] <= mem[inner_cnt + 1];
                            mem[inner_cnt + 1] <= mem[inner_cnt];
                        end
                        inner_cnt <= inner_cnt + 4'd1;
                    end else begin
                        outer_cnt <= outer_cnt + 4'd1;
                        inner_cnt <= 4'd0;
                        if (outer_cnt == MAX_BATTERIES - 2) begin
                            compute_cnt <= 4'd0;
                            max_diff <= 8'd0;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (diff > max_diff) begin
                        max_diff <= diff;
                    end
                    if (compute_cnt < n - 1) begin
                        compute_cnt <= compute_cnt + 4'd1;
                    end else begin
                        state <= RESULT;
                    end
                end
                
                RESULT: begin
                    result <= max_diff;
                    done <= 1'b1;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    if (start) begin
                        done <= 1'b0;
                        copy_cnt <= 4'd0;
                        state <= COPY;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule