module replace_spaces (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [7:0] char_out,
    output reg char_valid_out,
    output reg done,
    output reg char_read
);

// Parameters for states
localparam IDLE = 3'd0,
        READ_CHAR = 1,
        CHECK_SPACE = 2,
        OUTPUT_CHAR = 3,
        WAIT_FOR_NEXT = 4,
        FINISHED = 5;

// Registers
reg [7:0] current_char;
reg [2:0] state;
reg [1:0] count;
reg [3:0] position;
reg char_read_pulse; // for generating char_read output

// Clock and reset logic
always_ff @(posedge clk) begin
    if (!rst_n) begin
        current_char <= 8'd0;
        state <= IDLE;
        count <= 2'd0;
        position <= 4'd0;
        char_read_pulse <= 1'b0;
    end else begin
        case (state)
            IDLE: 
                if (start) begin
                    state <= READ_CHAR;
                end else begin
                    state <= IDLE;
                end
            READ_CHAR: 
                if (char_valid) begin
                    current_char <= char_in;
                    state <= CHECK_SPACE;
                end
            CHECK_SPACE: 
                if (current_char == 8'h20) begin // it's a space
                    state <= OUTPUT_CHAR;
                    count <= 2'd0;
                    position <= position + 1;
                end else begin
                    position <= position + 1;
                    state <= WAIT_FOR_NEXT;
                end
            OUTPUT_CHAR: 
                case (count)
                    2'd0: count <= 1'd1; // '%'
                    2'd1: count <= 1'd2; // '0'
                    2'd2: begin
                        count <= 1'd0;
                        state <= WAIT_FOR_NEXT;
                    end
                endcase
            WAIT_FOR_NEXT: 
                if (position >= 4'd8) begin // max input chars reached
                    state <= FINISHED;
                end else if (char_valid && (char_in != 8'h00)) begin // next char available and not null
                    state <= READ_CHAR;
                end else begin
                    state <= FINISHED;
                end
            FINISHED: 
                state <= FINISHED;
        endcase
    end
end

// Combinational logic for outputs
always_comb begin
    char_out = 8'd0;
    char_valid_out = 1'b0;
    case (state)
        CHECK_SPACE: 
            if (current_char != 8'h20) begin // non-space character
                char_out = current_char;
                char_valid_out = 1'b1;
            end
        OUTPUT_CHAR: 
            case (count)
                2'd0: char_out = 8'h25; char_valid_out = 1'b1; // '%'
                2'd1: char_out = 8'h30; char_valid_out = 1'b1; // '0'
                2'd2: char_out = 8'h30; char_valid_out = 1'b1; // '0'
            endcase
    endcase
end

// char_read output: pulse when starting from IDLE on start
always_ff @(posedge clk) begin
    if (!rst_n) 
        char_read_pulse <= 1'b0;
    else if (state == IDLE && start)
        char_read_pulse <= !char_read_pulse;
    else 
        char_read_pulse <= 1'b0;
end

assign char_read = char_read_pulse;
assign done = (state == FINISHED);

endmodule