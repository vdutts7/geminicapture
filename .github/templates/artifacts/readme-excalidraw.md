<!--
  artifact: readme-excalidraw
  path: $GHT/.github/templates/artifacts/readme-excalidraw.md
  command: $CURCMDS/git/readme-excalidraw.md  (/git/readme-excalidraw)
  diagram: $GHT/.github/templates/artifacts/readme-excalidraw.excalidraw
  plan: $GHT/.github/templates/artifacts/readme-excalidraw.plan.json
  generator: $SKILLS/diagram → excalidraw branch OR Documents/a/excalidraw-skill/scripts/generate.py
  form: HTML compare table (icon col 40x40) + link to editable .excalidraw
  fill: replace every {{PLACEHOLDER}} in this md; replace __PLACEHOLDER__ in .excalidraw / plan
  exemplar: gitty README table shape; diagram via https://github.com/vdutts7/excalidraw-skill
-->

<table>
<thead>
<tr>
<th align="left"></th>
<th align="left">{{COL_PATH}}</th>
<th align="left">{{COL_GET}}</th>
<th align="left">{{COL_VERDICT}}</th>
</tr>
</thead>
<tbody>
<tr>
<td align="left">
<img
src="{{ROW1_ICON_URL}}"
width="40"
height="40"
alt="{{ROW1_ICON_ALT}}"
/>
</td>
<td align="left">
<ul><li><code>{{ROW1_PATH}}</code></li></ul>
</td>
<td align="left">
<ul>
<li>{{ROW1_GET_1}}</li>
<li>{{ROW1_GET_2}}</li>
<li>{{ROW1_GET_3}}</li>
</ul>
</td>
<td align="left">❌<br/><br/>{{ROW1_VERDICT}}</td>
</tr>
<tr>
<td align="left">
<img
src="{{ROW2_ICON_URL}}"
width="40"
height="40"
alt="{{ROW2_ICON_ALT}}"
/>
</td>
<td align="left">
<ul><li><code>{{ROW2_PATH}}</code></li></ul>
</td>
<td align="left">
<ul>
<li>{{ROW2_GET_1}}</li>
<li>{{ROW2_GET_2}}</li>
<li>{{ROW2_GET_3}}</li>
</ul>
</td>
<td align="left">❌<br/><br/>{{ROW2_VERDICT}}</td>
</tr>
<tr>
<td align="left">
<img
src="{{ROW3_ICON_URL}}"
width="40"
height="40"
alt="{{ROW3_ICON_ALT}}"
/>
</td>
<td align="left">
<ul><li><code>{{ROW3_PATH}}</code></li></ul>
</td>
<td align="left">
<ul>
<li>{{ROW3_GET_1}}</li>
<li>{{ROW3_GET_2}}</li>
<li>{{ROW3_GET_3}}</li>
</ul>
</td>
<td align="left">✅<br/><br/>{{ROW3_VERDICT}}</td>
</tr>
</tbody>
</table>

<p align="center">
  <img
    src="{{SVG_REL_PATH}}"
    alt="{{SVG_ALT}}"
    width="720"
  />
</p>

[`{{EXCALIDRAW_BASENAME}}`]({{EXCALIDRAW_REL_PATH}}) — drag + drop into [excalidraw.com](https://excalidraw.com) (Load from file)
