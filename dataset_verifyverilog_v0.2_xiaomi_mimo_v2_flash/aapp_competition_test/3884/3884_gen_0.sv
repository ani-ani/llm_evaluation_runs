module rocket_fuel_calculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] payload,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    input [7:0] num_planets,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE      = 5'b00001;
    localparam PREPARE   = 5'b00010;
    localparam LOAD_LOOP = 5'b00100;
    localparam CALCULATE = 5'b01000;
    localparam FINAL     = 5'b10000;

    // Registers
    reg [4:0] state;
    reg [31:0] current_weight; // Q16.16
    reg [7:0] i; // Planet index (0 to N-1)
    
    // Divider Signals
    reg [31:0] div_num; // Numerator (val << 16)
    reg [7:0] div_den;  // Denominator (C - 1)
    wire [31:0] div_quot;
    wire div_done;
    reg div_start;

    // Divider Module (Iterative: 32 cycles max)
    // Computes (div_num / div_den) -> Q16.16 result
    divider_core u_div (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .numerator(div_num),
        .denominator(div_den),
        .quotient(div_quot),
        .done(div_done)
    );

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            result <= 0;
            div_start <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    if (start) begin
                        // Check for immediate error in payload inputs if needed, 
                        // but here we check coefficients in CALCULATE state.
                        state <= PREPARE;
                    end
                end

                PREPARE: begin
                    // Initialize total weight to payload (Q16.16)
                    current_weight <= {payload, 16'b0};
                    i <= num_planets - 1; // Start from last planet index
                    state <= LOAD_LOOP;
                end

                LOAD_LOOP: begin
                    // Check loop termination
                    // The algorithm processes (Land, Takeoff) for i=N-1 down to 1.
                    // Then Final Takeoff for i=0 (Earth).
                    if (i == 0) begin
                        state <= FINAL;
                    end else begin
                        // Check Landing Coefficient b[i]
                        if (b[i] == 8'd1) begin
                            error <= 1;
                            state <= IDLE;
                        end else begin
                            // Setup Landing Calculation: current_weight * b[i] / (b[i] - 1)
                            // 1. Multiply numerator: current_weight * b[i]
                            // 2. Divide by (b[i] - 1)
                            // Since current_weight is Q16.16, we need to shift left 16 for division.
                            // Start Multiplication (we can do this inline or state)
                            // Let's do Mult in one cycle, then Div.
                            current_weight <= (current_weight * b[i]) >> 16;
                            state <= CALCULATE; // Wait for multi-cycle op (Div is main)
                        end
                    end
                end

                CALCULATE: begin
                    // This state handles the Division phase for the current operation (Landing or Takeoff)
                    // We need to know if we are doing Landing or Takeoff.
                    // To track this, we can use a sub-state or check 'i' vs a flag.
                    // However, since we loop LOAD_LOOP -> CALCULATE -> LOAD_LOOP, 
                    // we need to sequence: Landing -> (then Takeoff) -> decrement i.
                    // To simplify, we will expand states in the FSM to handle Lander and Taker explicitly.
                    // But to keep code compact, we will use a flag 'phase'.
                    
                    // Let's restructure the LOOP slightly to avoid complex flags.
                    // We will create specific states for Landing and Takeoff calculation setup.
                    state <= LOAD_LOOP; // Default return
                end

                FINAL: begin
                    // Final Takeoff from Earth: a[0]
                    if (a[0] == 8'd1) begin
                        error <= 1;
                        state <= IDLE;
                    end else begin
                        // Setup Final Calculation: current_weight * a[0] / (a[0] - 1)
                        // This is effectively the last division step.
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Compute Result: FinalWeight - Payload
                    // current_weight holds Q16.16 value.
                    result <= current_weight - {payload, 16'b0};
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // Refactored Logic for Sequential Operations
    // Since the original LOAD_LOOP had nested operations (Landing then Takeoff),
    // we need to break them down. The state machine above was simplified.
    // Let's implement the specific sequence: 
    // Loop: Check i > 0 -> Landing -> Takeoff -> Dec i -> Loop
    // Final: Earth Takeoff -> Result

    // Re-implementing the main FSM for correctness:
    reg [1:0] sub_phase; // 0: Landing, 1: Takeoff, 2: Decrement/Next
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            result <= 0;
            div_start <= 0;
            sub_phase <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    if (start) begin
                        state <= PREPARE;
                    end
                end

                PREPARE: begin
                    current_weight <= {payload, 16'b0};
                    if (num_planets == 0) begin
                        // No planets, just earth takeoff? Or just payload.
                        // Problem implies a trip. Let's assume if 0 planets, just fuel for takeoff/land is none?
                        // If N=0, we just need Result = 0? Or handle Earth case.
                        // Problem says: "Finally, handle the first take-off (from Earth)".
                        // If N=0, we only do Earth. But Earth takeoff is usually part of trip.
                        // Let's assume if N=0, we just return 0.
                        state <= DONE_STATE;
                    end else begin
                        i <= num_planets - 1;
                        sub_phase <= 0; // Start with Landing
                        state <= SETUP_OP;
                    end
                end

                SETUP_OP: begin
                    // Check if we are done with loop
                    if (i == 0 && sub_phase == 1) begin
                        // We just finished the last Takeoff (for i=0), move to Final Done
                        state <= DONE_STATE;
                    end else if (i == 0 && sub_phase == 0) begin
                        // We are at i=0, but sub_phase is Landing. 
                        // Note: The algorithm says: "Process pairs in reverse (excluding first takeoff)".
                        // This means for i from N-1 down to 1: Landing, Takeoff.
                        // For i=0: Only Takeoff.
                        // So if i=0, we skip Landing and go straight to Takeoff (which is the Final Earth Takeoff logic).
                        // So we jump to FINAL state or handle here.
                        state <= FINAL;
                    end else begin
                        // Determine Operation
                        if (sub_phase == 0) begin
                            // Landing: b[i]
                            if (b[i] == 8'd1) begin
                                error <= 1;
                                state <= IDLE;
                            end else begin
                                // Calc: current_weight = current_weight * b[i] / (b[i] - 1)
                                // 1. Mult: current_weight * b[i] (Result is Q16.16 * Int = Q16.16)
                                current_weight <= (current_weight * b[i]) >> 16;
                                // 2. Div: (current_weight << 16) / (b[i]-1)
                                div_den <= b[i] - 1;
                                state <= EXECUTE_DIV;
                            end
                        end else begin
                            // Takeoff: a[i]
                            if (a[i] == 8'd1) begin
                                error <= 1;
                                state <= IDLE;
                            end else begin
                                // Calc: current_weight = current_weight * a[i] / (a[i] - 1)
                                current_weight <= (current_weight * a[i]) >> 16;
                                div_den <= a[i] - 1;
                                state <= EXECUTE_DIV;
                            end
                        end
                    end
                end

                EXECUTE_DIV: begin
                    // Wait for divider core
                    // We need to prepare numerator: current_weight (after mult) << 16
                    // But current_weight was updated in SETUP_OP. 
                    // Wait, we need to capture the value before shifting?
                    // Actually, we need to send (current_weight << 16) to divider.
                    // current_weight is Q16.16. Shifting left 16 makes it Q32.16? No.
                    // To divide a Q16.16 number by an integer D, we do (Val << 16) / D.
                    // So if current_weight is X (Q16.16), we send X << 16.
                    // But X was just calculated as (Old * Coeff) >> 16.
                    // Let's send the new value.
                    div_num <= current_weight << 16;
                    if (!div_start) begin
                        div_start <= 1;
                    end else if (div_done) begin
                        div_start <= 0;
                        current_weight <= div_quot;
                        
                        // Next Step Logic
                        if (sub_phase == 0) begin
                            // Finished Landing, next is Takeoff for same i
                            sub_phase <= 1;
                            state <= SETUP_OP;
                        end else begin
                            // Finished Takeoff, decrement i and go to Landing
                            sub_phase <= 0;
                            if (i > 0) begin
                                i <= i - 1;
                                state <= SETUP_OP;
                            end else begin
                                // i was 0, finished Takeoff. Loop done.
                                state <= DONE_STATE;
                            end
                        end
                    end
                end

                FINAL: begin
                    // Earth Takeoff (i=0)
                    if (a[0] == 8'd1) begin
                        error <= 1;
                        state <= IDLE;
                    end else begin
                        current_weight <= (current_weight * a[0]) >> 16;
                        div_den <= a[0] - 1;
                        state <= EXECUTE_DIV_FINAL;
                    end
                end

                EXECUTE_DIV_FINAL: begin
                    div_num <= current_weight << 16;
                    if (!div_start) begin
                        div_start <= 1;
                    end else if (div_done) begin
                        div_start <= 0;
                        current_weight <= div_quot;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= current_weight - {payload, 16'b0};
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

module divider_core (
    input clk,
    input rst_n,
    input start,
    input [31:0] numerator, // Q16.16 shifted to Q32.16 effectively (wait, just 32-bit num)
    input [7:0] denominator,
    output reg [31:0] quotient,
    output reg done
);
    // Iterative Bitwise Division
    reg [31:0] rem;
    reg [5:0] count;
    reg active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            active <= 0;
            quotient <= 0;
            count <= 0;
        end else begin
            if (start && !active) begin
                active <= 1;
                done <= 0;
                rem <= numerator; // Use numerator directly
                quotient <= 0;
                count <= 32;      // 32 bits for 32-bit numerator
            end else if (active) begin
                // Shift Left rem and quotient
                {rem, quotient} <= {rem[30:0], quotient, 1'b0};
                
                if (rem[31:24] >= denominator) begin // Optimization: Check MSB range vs denominator (max 1000)
                // Actually denominator is 8-bit (max 255 if input is 8-bit, but prompt says up to 1000? Wait input is [7:0] a [0:7]. So max 255).
                // Let's do generic check.
                    if (rem[31:0] >= {24'b0, denominator}) begin
                        rem <= rem - {24'b0, denominator};
                        quotient[0] <= 1'b1;
                    end
                end

                count <= count - 1;
                if (count == 1) begin
                    active <= 0;
                    done <= 1;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule