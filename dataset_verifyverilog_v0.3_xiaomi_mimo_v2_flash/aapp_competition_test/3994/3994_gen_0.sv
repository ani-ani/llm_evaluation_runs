module lights_max (
    input clk,
    input rst_n,
    input start,
    input [7:0] initial_state,
    input [2:0] a [0:7],
    input [2:0] b [0:7],
    output reg [7:0] max_count
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] SIMULATE = 3'd1;
localparam [2:0] UPDATE_MAX = 3'd2;
localparam [2:0] NEXT_TIME = 3'd3;
localparam [2:0] DONE = 3'd4;

// Registers
reg [2:0] state;
reg [6:0] time_counter;
reg [2:0] light_counter;
reg [7:0] current_states;
reg [7:0] max_count_reg;
reg [7:0] current_count;
reg [2:0] toggle_count;

// Internal wires
wire should_toggle;
wire light_on;

assign light_on = current_states[light_counter];

// Check if this light should toggle at current time
assign should_toggle = (time_counter >= b[light_counter]) && 
                      (((time_counter - b[light_counter]) % a[light_counter]) == 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        time_counter <= 7'd0;
        light_counter <= 3'd0;
        current_states <= 8'b0;
        max_count_reg <= 8'd0;
        current_count <= 8'd0;
        max_count <= 8'd0;
        toggle_count <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    current_states <= initial_state;
                    time_counter <= 7'd0;
                    light_counter <= 3'd0;
                    max_count_reg <= 8'd0;
                    current_count <= 8'd0;
                    toggle_count <= 3'd0;
                    // Calculate initial count
                    current_count <= initial_state[0] + initial_state[1] + 
                                   initial_state[2] + initial_state[3] + 
                                   initial_state[4] + initial_state[5] + 
                                   initial_state[6] + initial_state[7];
                    state <= UPDATE_MAX;
                end
            end
            
            SIMULATE: begin
                // Process toggles for current light
                if (should_toggle) begin
                    current_states[light_counter] <= ~light_on;
                    if (light_on) begin
                        current_count <= current_count - 8'd1;
                    end else begin
                        current_count <= current_count + 8'd1;
                    end
                    toggle_count <= toggle_count + 3'd1;
                end
                
                if (light_counter == 3'd7) begin
                    light_counter <= 3'd0;
                    state <= UPDATE_MAX;
                end else begin
                    light_counter <= light_counter + 3'd1;
                end
            end
            
            UPDATE_MAX: begin
                if (current_count > max_count_reg) begin
                    max_count_reg <= current_count;
                end
                state <= NEXT_TIME;
            end
            
            NEXT_TIME: begin
                if (time_counter == 7'd120) begin
                    max_count <= max_count_reg;
                    state <= DONE;
                end else begin
                    time_counter <= time_counter + 7'd1;
                    light_counter <= 3'd0;
                    toggle_count <= 3'd0;
                    state <= SIMULATE;
                end
            end
            
            DONE: begin
                // Stay done until reset
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule