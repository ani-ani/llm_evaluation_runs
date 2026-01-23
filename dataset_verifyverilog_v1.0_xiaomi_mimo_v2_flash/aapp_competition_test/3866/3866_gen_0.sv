module lucky_permutation_triple (
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
localparam [1:0] IDLE  = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] FINISH = 2'd2;

reg [1:0] state;
reg [3:0] i;
reg n_odd;
reg n_valid;
reg [7:0] c_val;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        i <= 4'd0;
        n_odd <= 1'b0;
        n_valid <= 1'b0;
        // Initialize all arrays
        a[0] <= 8'd0; a[1] <= 8'd0; a[2] <= 8'd0; a[3] <= 8'd0;
        a[4] <= 8'd0; a[5] <= 8'd0; a[6] <= 8'd0; a[7] <= 8'd0;
        b[0] <= 8'd0; b[1] <= 8'd0; b[2] <= 8'd0; b[3] <= 8'd0;
        b[4] <= 8'd0; b[5] <= 8'd0; b[6] <= 8'd0; b[7] <= 8'd0;
        c[0] <= 8'd0; c[1] <= 8'd0; c[2] <= 8'd0; c[3] <= 8'd0;
        c[4] <= 8'd0; c[5] <= 8'd0; c[6] <= 8'd0; c[7] <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Check validity: n must be odd and <= 8 (and n >= 1)
                    n_odd <= n[0];
                    n_valid <= (n[0] == 1'b1) && (n <= 8'd8) && (n != 4'd0);
                    state <= COMPUTE;
                    i <= 4'd0;
                end
            end
            COMPUTE: begin
                // Computation logic
                if (i < 4'd8) begin
                    if (n_valid && (i < n)) begin
                        // a[i] = i, b[i] = i
                        a[i] <= {4'd0, i};
                        b[i] <= {4'd0, i};
                        // c[i] = (2*i) % n
                        // Compute 2*i
                        if (2 * i >= n) begin
                            c_val <= 2 * i - n;
                        end else begin
                            c_val <= 2 * i;
                        end
                        c[i] <= c_val;
                    end else begin
                        // i >= n or invalid n: set to 0
                        a[i] <= 8'd0;
                        b[i] <= 8'd0;
                        c[i] <= 8'd0;
                    end
                    i <= i + 4'd1;
                end else begin
                    // All 8 elements processed
                    valid <= n_valid;
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