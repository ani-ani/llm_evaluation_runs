module LuckyPermutationTriple(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n_in,
    output reg valid,
    output reg [4:0] addr_a,
    output reg [4:0] data_a,
    output reg [4:0] addr_b,
    output reg [4:0] data_b,
    output reg [4:0] addr_c,
    output reg [4:0] data_c,
    output reg wr_en,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state;
    reg [4:0] n_val;
    reg [4:0] i;
    reg [4:0] sum;
    reg [4:0] c_val;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            n_val <= 5'd0;
            i <= 5'd0;
            sum <= 5'd0;
            c_val <= 5'd0;
            addr_a <= 5'd0;
            data_a <= 5'd0;
            addr_b <= 5'd0;
            data_b <= 5'd0;
            addr_c <= 5'd0;
            data_c <= 5'd0;
            wr_en <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    wr_en <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        n_val <= n_in;
                    end
                end
                
                CHECK: begin
                    wr_en <= 1'b0;
                    if (n_val[0] == 1'b0) begin
                        valid <= 1'b0;
                        state <= FINISH;
                    end else begin
                        valid <= 1'b1;
                        state <= COMPUTE;
                        i <= 5'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    wr_en <= 1'b1;
                    addr_a <= i;
                    data_a <= i;
                    addr_b <= i;
                    data_b <= i;
                    sum <= i + i;
                    if (sum >= n_val) begin
                        c_val <= sum - n_val;
                    end else begin
                        c_val <= sum;
                    end
                    addr_c <= i;
                    data_c <= c_val;
                    
                    if (i == n_val - 1'b1 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 1'b1;
                    end
                end
                
                FINISH: begin
                    wr_en <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule