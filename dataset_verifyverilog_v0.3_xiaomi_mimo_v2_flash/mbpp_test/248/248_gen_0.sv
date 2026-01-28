module harmonic_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [2:0] IDLE        = 3'd0;
localparam [2:0] START       = 3'd1;
localparam [2:0] CALC        = 3'd2;
localparam [2:0] WAIT_DIV    = 3'd3;
localparam [2:0] ACCUM       = 3'd4;
localparam [2:0] FINISH      = 3'd5;

// Registers
reg [2:0] state, next_state;
reg [7:0] counter;              // Current term (i)
reg [7:0] iterations_remaining; // For delay simulation
reg [15:0] accumulator;         // Q8.8 fixed-point sum
reg [15:0] term_value;          // Q8.8 value of 1/i
reg division_done;              // Division completion flag

// Constant for 1.0 in Q8.8 format
localparam [15:0] ONE_POINT_ZERO = 16'h0100;

// Reciprocal lookup table (combinational)
reg [15:0] reciprocal_lut [0:255];

// Initialize LUT in combinational logic
integer i;
always @(*) begin
    reciprocal_lut[0] = 16'hFFFF;
    reciprocal_lut[1] = 16'h0100;  // 1.0
    reciprocal_lut[2] = 16'h0080;  // 0.5
    reciprocal_lut[3] = 16'h0055;  // 0.333
    reciprocal_lut[4] = 16'h0040;  // 0.25
    reciprocal_lut[5] = 16'h0033;  // 0.2
    reciprocal_lut[6] = 16'h002A;  // 0.167
    reciprocal_lut[7] = 16'h0024;  // 0.143
    reciprocal_lut[8] = 16'h0020;  // 0.125
    reciprocal_lut[9] = 16'h001C;  // 0.111
    reciprocal_lut[10] = 16'h0019; // 0.1
    // For larger n, use approximation: (256*256)/n
    for (i = 11; i <= 255; i = i + 1) begin
        reciprocal_lut[i] = (256 * 256) / i;
    end
end

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        done <= 1'b0;
        counter <= 8'd0;
        iterations_remaining <= 8'd0;
        accumulator <= 16'd0;
        term_value <= 16'd0;
        division_done <= 1'b0;
    end else begin
        state <= next_state;
    end
end

// Next state and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset handled in state register block
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Initialize: start from n down to 1
                    counter <= n;
                    accumulator <= 16'd0;
                end
            end
            
            START: begin
                // Wait one cycle for LUT access
                iterations_remaining <= 8'd120; // Approximation delay
                division_done <= 1'b0;
            end
            
            CALC: begin
                // Get 1/counter from LUT
                term_value <= reciprocal_lut[counter];
                iterations_remaining <= 8'd120; // Simulated delay
                division_done <= 1'b0;
            end
            
            WAIT_DIV: begin
                // Simulate division delay
                if (iterations_remaining > 8'd0) begin
                    iterations_remaining <= iterations_remaining - 8'd1;
                    division_done <= 1'b0;
                end else begin
                    division_done <= 1'b1;
                end
            end
            
            ACCUM: begin
                if (division_done) begin
                    // Add 1/counter to accumulator
                    accumulator <= accumulator + term_value;
                    // Move to next term
                    counter <= counter - 8'd1;
                end
            end
            
            FINISH: begin
                result <= accumulator;
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state transition logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = START;
            end
        end
        
        START: begin
            if (counter >= 8'd2) begin
                next_state = CALC;
            end else begin
                // Base case: harmonic_sum(1) = 1
                next_state = FINISH;
            end
        end
        
        CALC: begin
            next_state = WAIT_DIV;
        end
        
        WAIT_DIV: begin
            if (division_done) begin
                next_state = ACCUM;
            end
        end
        
        ACCUM: begin
            if (counter >= 8'd2) begin
                next_state = CALC;
            end else begin
                // Add 1.0 for i=1 and finish
                accumulator = accumulator + ONE_POINT_ZERO;
                next_state = FINISH;
            end
        end
        
        FINISH: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule