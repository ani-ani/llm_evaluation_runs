module array_overlap_checker(
    input wire clk,
    input wire rst_n,
    input wire [7:0] arr_a [0:7],
    input wire [7:0] arr_b [0:7],
    input wire [3:0] len_a,
    input wire [3:0] len_b,
    output reg overlapping
);

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] a_index;
    reg [2:0] b_index;
    reg match_found;

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPARE   = 3'd1;
    localparam [2:0] FINISHED  = 3'd2;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = COMPARE;
            COMPARE: begin
                if (match_found) begin
                    next_state = FINISHED;
                end else if (a_index == len_a - 1'b1 && b_index == len_b - 1'b1) begin
                    next_state = FINISHED;
                end else if (b_index == len_b - 1'b1) begin
                    next_state = COMPARE;
                end else begin
                    next_state = COMPARE;
                end
            end
            FINISHED: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a_index <= 3'd0;
            b_index <= 3'd0;
            match_found <= 1'b0;
            overlapping <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Index and comparison logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_index <= 3'd0;
            b_index <= 3'd0;
            match_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    a_index <= 3'd0;
                    b_index <= 3'd0;
                    match_found <= 1'b0;
                    overlapping <= 1'b0;
                end
                COMPARE: begin
                    if (!match_found) begin
                        if (arr_a[a_index] == arr_b[b_index]) begin
                            match_found <= 1'b1;
                            overlapping <= 1'b1;
                        end
                        if (b_index == len_b - 1'b1) begin
                            a_index <= a_index + 1'b1;
                            b_index <= 3'd0;
                        end else begin
                            b_index <= b_index + 1'b1;
                        end
                    end
                end
                FINISHED: begin
                    if (match_found) begin
                        overlapping <= 1'b1;
                    end else begin
                        overlapping <= 1'b0;
                    end
                end
                default: begin
                    a_index <= 3'd0;
                    b_index <= 3'd0;
                    match_found <= 1'b0;
                end
            endcase
        end
    end

endmodule