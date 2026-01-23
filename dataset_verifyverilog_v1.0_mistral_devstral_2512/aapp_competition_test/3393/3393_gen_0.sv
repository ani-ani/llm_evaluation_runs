module course_selection (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  k,
    input  wire [7:0]  diff [0:7],
    input  wire [0:7]  is_level2,
    input  wire [2:0]  prereq_idx [0:7],
    output reg  [15:0] result,
    output reg         done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_MIN  = 3'd1;
    localparam [2:0] LOOP      = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] INCREMENT = 3'd5;
    localparam [2:0] DONE      = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [7:0] mask;
    reg [15:0] min_sum;
    reg [3:0] popcount;
    reg [15:0] current_sum;
    reg valid;
    reg [3:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            min_sum <= 16'd65535;
            popcount <= 4'd0;
            current_sum <= 16'd0;
            valid <= 1'b1;
            i <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_MIN;
                    end
                end

                INIT_MIN: begin
                    min_sum <= 16'd65535;
                    mask <= 8'd0;
                    state <= LOOP;
                end

                LOOP: begin
                    // Initialize loop variables
                    popcount <= 4'd0;
                    current_sum <= 16'd0;
                    valid <= 1'b1;
                    i <= 4'd0;
                    state <= CHECK;
                end

                CHECK: begin
                    // Compute popcount, sum, and validity
                    if (i < 4'd8) begin
                        if (mask[i]) begin
                            popcount <= popcount + 4'd1;
                            current_sum <= current_sum + diff[i];
                            if (is_level2[i] && !mask[prereq_idx[i]]) begin
                                valid <= 1'b0;
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (valid && (popcount == k) && (current_sum < min_sum)) begin
                        min_sum <= current_sum;
                    end
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    mask <= mask + 8'd1;
                    if (mask == 8'd0) begin
                        state <= DONE;
                    end else begin
                        state <= LOOP;
                    end
                end

                DONE: begin
                    result <= min_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule