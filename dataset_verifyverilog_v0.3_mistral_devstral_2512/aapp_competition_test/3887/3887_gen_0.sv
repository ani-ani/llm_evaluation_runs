module rebus_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_positive,  // Number of positive terms (1-8)
    input wire [3:0] num_negative,  // Number of negative terms (0-8)
    input wire [19:0] n,            // Target value (1-1,000,000)
    output reg done,
    output reg possible,
    output reg [19:0] positive_terms [0:7],  // Positive terms (8 elements)
    output reg [19:0] negative_terms [0:7]   // Negative terms (8 elements)
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PRECOMPUTE = 3'd1;
localparam [2:0] CHECK = 3'd2;
localparam [2:0] ASSIGN_POSITIVE = 3'd3;
localparam [2:0] ASSIGN_NEGATIVE = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

reg [2:0] state;
reg signed [31:0] adjustment;
reg [31:0] rem;
reg [3:0] index;
reg [31:0] limit_positive, limit_negative;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        possible <= 1'b0;
        adjustment <= 32'd0;
        rem <= 32'd0;
        index <= 4'd0;
        limit_positive <= 32'd0;
        limit_negative <= 32'd0;
        // Initialize all terms to 1
        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            positive_terms[i] <= 20'd1;
            negative_terms[i] <= 20'd1;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PRECOMPUTE;
                end
            end
            
            PRECOMPUTE: begin
                // Compute adjustment = n - (num_positive - num_negative)
                adjustment <= $signed(n) - $signed(num_positive) + $signed(num_negative);
                // Maximum adjustment possible
                limit_positive <= $signed(num_positive) * $signed(n - 1);
                limit_negative <= $signed(num_negative) * $signed(n - 1);
                state <= CHECK;
            end
            
            CHECK: begin
                if (adjustment >= 0) begin
                    if (adjustment <= limit_positive) begin
                        possible <= 1'b1;
                        rem <= adjustment;
                        index <= 4'd0;
                        state <= ASSIGN_POSITIVE;
                    end else begin
                        possible <= 1'b0;
                        state <= DONE_STATE;
                    end
                end else begin
                    if (-adjustment <= limit_negative) begin
                        possible <= 1'b1;
                        rem <= -adjustment;
                        index <= 4'd0;
                        state <= ASSIGN_NEGATIVE;
                    end else begin
                        possible <= 1'b0;
                        state <= DONE_STATE;
                    end
                end
            end
            
            ASSIGN_POSITIVE: begin
                if (index < num_positive) begin
                    if (rem > $signed(n - 1)) begin
                        positive_terms[index] <= 20'd1 + (n - 1);
                        rem <= rem - $signed(n - 1);
                    end else begin
                        positive_terms[index] <= 20'd1 + rem;
                        rem <= 32'd0;
                    end
                    index <= index + 4'd1;
                end else begin
                    state <= DONE_STATE;
                end
            end
            
            ASSIGN_NEGATIVE: begin
                if (index < num_negative) begin
                    if (rem > $signed(n - 1)) begin
                        negative_terms[index] <= 20'd1 + (n - 1);
                        rem <= rem - $signed(n - 1);
                    end else begin
                        negative_terms[index] <= 20'd1 + rem;
                        rem <= 32'd0;
                    end
                    index <= index + 4'd1;
                end else begin
                    state <= DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule