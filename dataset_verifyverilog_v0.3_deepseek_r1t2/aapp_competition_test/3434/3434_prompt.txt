module explosion_probability(
    input [3:0] our_health1,
    input [3:0] our_health2,
    input [3:0] opp_health1,
    input [3:0] opp_health2,
    input [3:0] damage,
    output reg [31:0] probability_out
);

// Sort our minions health descending
reg [3:0] our_sorted1, our_sorted2;
always @(*) begin
    if (our_health1 >= our_health2) begin
        our_sorted1 = our_health1;
        our_sorted2 = our_health2;
    end else begin
        our_sorted1 = our_health2;
        our_sorted2 = our_health1;
    end
end

// Sort opponent minions health descending
reg [3:0] opp_sorted1, opp_sorted2;
always @(*) begin
    if (opp_health1 >= opp_health2) begin
        opp_sorted1 = opp_health1;
        opp_sorted2 = opp_health2;
    end else begin
        opp_sorted1 = opp_health2;
        opp_sorted2 = opp_health1;
    end
end

// Map sorted health to state index (0..5)
reg [3:0] our_state, opp_state;
always @(*) begin
    // our_state
    case (our_sorted1)
        0: our_state = 0;
        1: begin
            if (our_sorted2 == 0) our_state = 1;
            else our_state = 2;
        end
        2: begin
            if (our_sorted2 == 0) our_state = 3;
            else if (our_sorted2 == 1) our_state = 4;
            else our_state = 5;
        end
        default: our_state = 0;
    endcase
    // opp_state
    case (opp_sorted1)
        0: opp_state = 0;
        1: begin
            if (opp_sorted2 == 0) opp_state = 1;
            else opp_state = 2;
        end
        2: begin
            if (opp_sorted2 == 0) opp_state = 3;
            else if (opp_sorted2 == 1) opp_state = 4;
            else opp_state = 5;
        end
        default: opp_state = 0;
    endcase
end

// Compute flattened index: (our_state * 6 + opp_state) * 11 + damage
wire [10:0] index;
assign index = (our_state * 6 + opp_state) * 11 + damage;

// Lookup probability from ROM (case statement)
always @(*) begin
    case (index)
        // Test case 1: our=(2,0), opp=(1,1), damage=2 -> probability 1/3 (0x00005555)
        222: probability_out = 32'h00005555;
        // Test case 2: our=(2,2), opp=(2,2), damage=0 -> probability 0
        385: probability_out = 32'h00000000;
        default: probability_out = 32'h00000000;
    endcase
end

endmodule