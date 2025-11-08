module TopModule (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  in,
    output wire [23:0] out_bytes,
    output reg         done
);

typedef enum logic [1:0] {
    IDLE,
    GOT_BYTE1,
    GOT_BYTE2,
    ASSERT_DONE
} state_t;

reg [1:0] state, next_state;
reg [7:0] byte1, byte2, byte3;

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: next_state = in[3] ? GOT_BYTE1 : IDLE;
        GOT_BYTE1: next_state = GOT_BYTE2;
        GOT_BYTE2: next_state = ASSERT_DONE;
        ASSERT_DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        byte1 <= 8'b0;
        byte2 <= 8'b0;
        byte3 <= 8'b0;
    end else begin
        case (state)
            IDLE: byte1 <= in[3] ? in : byte1;
            GOT_BYTE1: byte2 <= in;
            GOT_BYTE2: byte3 <= in;
            default: begin end
        endcase
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        done <= 1'b0;
    end else begin
        done <= (state == ASSERT_DONE);
    end
end

assign out_bytes = {byte1, byte2, byte3};

endmodule