module compare_one (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire type_a,
    input wire type_b,
    input wire signed [15:0] val_a,
    input wire signed [15:0] val_b,
    input wire [7:0] str_a,
    input wire [7:0] str_b,
    output reg signed [15:0] result_val,
    output reg result_type,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] PARSE_A  = 3'd1;
    localparam [2:0] PARSE_B  = 3'd2;
    localparam [2:0] COMPARE  = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg signed [15:0] fp_a;
    reg signed [15:0] fp_b;
    reg signed [15:0] stored_val_a;
    reg signed [15:0] stored_val_b;
    reg stored_type_a;
    reg stored_type_b;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;

    // Combinational logic for next state
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_A;
            end
            PARSE_A: begin
                next_state = PARSE_B;
            end
            PARSE_B: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_val <= 16'd0;
            result_type <= 1'b0;
            valid <= 1'b0;
            fp_a <= 16'd0;
            fp_b <= 16'd0;
            stored_val_a <= 16'd0;
            stored_val_b <= 16'd0;
            stored_type_a <= 1'b0;
            stored_type_b <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        stored_val_a <= val_a;
                        stored_val_b <= val_b;
                        stored_type_a <= type_a;
                        stored_type_b <= type_b;
                    end
                end

                PARSE_A: begin
                    if (stored_type_a == 1'b0) begin
                        fp_a <= stored_val_a;
                    end else begin
                        // Convert string to Q8.8 fixed-point
                        // str_a[7:4] = tens, str_a[3:0] = ones
                        fp_a <= ({4'd0, str_a[7:4], str_a[3:0], 4'd0});
                    end
                end

                PARSE_B: begin
                    if (stored_type_b == 1'b0) begin
                        fp_b <= stored_val_b;
                    end else begin
                        // Convert string to Q8.8 fixed-point
                        fp_b <= ({4'd0, str_b[7:4], str_b[3:0], 4'd0});
                    end
                end

                COMPARE: begin
                    if (fp_a == fp_b) begin
                        valid <= 1'b1;
                        result_val <= 16'd0;
                        result_type <= 1'b0;
                    end else if (fp_a > fp_b) begin
                        valid <= 1'b1;
                        result_val <= stored_val_a;
                        result_type <= stored_type_a;
                    end else begin
                        valid <= 1'b1;
                        result_val <= stored_val_b;
                        result_type <= stored_type_b;
                    end
                end

                FINISH: begin
                    valid <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    result_val <= 16'd0;
                    result_type <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end
endmodule